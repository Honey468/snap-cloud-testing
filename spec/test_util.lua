-- Test Utilities
-- ==========
--
-- Simple utilites like creating users/projects
-- and mocks for common objects or services.
--
-- Written by Andrew Schmitt
--
-- Copyright (C) 2018 by Bernat Romagosa
--
-- This file is part of Snap Cloud.
--
-- Snap Cloud is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
local app = require 'app'
local db = package.loaded.db
local Users = package.loaded.Users
local Tokens = package.loaded.Tokens
local stringx = require 'pl.stringx'
local request = require('lapis.spec.server').request

-- Deletes all users and tokens from the database.
function clean_db()
    db.delete('tokens')
    db.delete('users')
end

local ten_days = 60 * 60 * 24 * 10

-- Create a token for the specified user with the specified purpose
-- @param expired whether the created token should be expired
function create_token(username, purpose, expired)
    local created_date = db.format_date()
    if expired then
        created_date = db.format_date(os.time() - ten_days)
    end
    Tokens:create({
        username = username,
        created = created_date,
        value = secure_token(),
        purpose = purpose
    })
end

function retrieve_user(username)
    return Users:find(username)
end

-- Creates a single user with a default email assigned: <username>@snap.berkeley.edu
-- @return the user model of the created user
function create_user(username, password, obj)
    obj = obj or {}
    local salt = secure_salt()
    return Users:create({
        created = db.format_date(),
        username = username,
        salt = salt,
        password = hash_password(password, salt),
        email = obj.email or (username .. '@snap.berkeley.edu'),
        verified = to_bool(obj.verified, true),
        isadmin = to_bool(obj.isadmin, false)
    })
end

function to_bool(nillable, default)
    if nillable == nil then
        return default
    end
    return nillable
end

-- The api expects passwords to be sent prehashed.
-- @return a hashed password that can be sent in api requests
function hash_for_api(password)
    return hash_password(password, '')
end

-- Given headers returned from a request parses the cookies into a table
function parse_cookies(headers)
    local result = {}
    for _, pair in ipairs(stringx.split(headers.set_cookie, ';')) do
        local parts = stringx.split(stringx.strip(pair), '=')
        result[parts[1]] = parts[2]
    end
    return result
end


function session_request(self, path, options)
    if options.headers then
        options.headers.Cookie = self.session
    else
        options.headers = {
            Cookie = self.session
        }
    end

    return request(path, options)
end

-- Returns a stateful session object that will keep the user logged in
-- @param [create_new_user] default: true if false then will not create a new user in the db
function create_session(username, api_password, create_new_user)
    if create_new_user == nil or create_new_user then
        create_user(username, api_password)
    end

    local s, b, h = request('/users/' .. username .. '/login', {
        method = 'POST',
        data = api_password,
        expect='json'
    })

    return {
        session = h.set_cookie,
        request = session_request
    }
end

return {
    clean_db = clean_db,
    create_token = create_token,
    create_user = create_user,
    hash_for_api = hash_for_api,
    parse_cookies = parse_cookies,
    create_session = create_session,
    retrieve_user = retrieve_user
}
