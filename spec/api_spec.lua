-- API tests
-- ==========
--
-- Some tests of the API.
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
local request = require('lapis.spec.server').request
local use_test_server = require('lapis.spec').use_test_server
local test_util = require 'test_util'

-- Some sample username/password combos to use in tests
local admin_user = 'test_admin'
local admin_password = test_util.hash_for_api('admin_test_123456')
local username = 'aaaschmitty'
local api_password = test_util.hash_for_api('test_123456')

describe('The login endpoint', function()
    use_test_server()

    before_each(function()
        test_util.clean_db()
    end)

    it('POST allows a valid user to login', function()
        test_util.create_user(username, api_password)

        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = api_password,
            expect='json'
        })

        assert.same(200, status)
        assert.is.truthy(body.message:find(username)) -- TODO: standardize to 'msg'
    end)

    it('POST returns the days remaining for a user with a valid token', function()
        test_util.create_user(username, api_password, {verified = false})
        test_util.create_token(username, 'verify_user', false)

        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = api_password,
            expect='json'
        })

        assert.same(200, status)
        assert.same(3, body.days_left)
    end)

    it('POST should error for a user with an expired token', function()
        test_util.create_user(username, api_password, {verified = false})
        test_util.create_token(username, 'verify_user', true)

        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = api_password,
            expect='json'
        })

        local error = body.errors[1]

        assert.same(401, status)
        assert.is.truthy(error:find('not') and error:find('validated'))
    end)

    it('POST should error for a user with wrong password', function()
        test_util.create_user(username, api_password)

        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = api_password .. 'a', -- append an invalid char
            expect='json'
        })

        assert.same(400, status)
        assert.same('wrong password', body.errors[1])
    end)

    it('POST should error for a non-existent user', function()
        -- don't create user first
        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = api_password,
            expect='json'
        })

        local error = body.errors[1]

        assert.same(404, status)
        assert.is.truthy(error:find('No user') and error:find('exists'))
    end)
    
    it('POST should error for a non-verified user with no token', function()
        test_util.create_user(username, api_password, {verified = false})

        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = api_password,
            expect='json'
        })

        local error = body.errors[1]

        assert.same(401, status)
        assert.is.truthy(error:find('not') and error:find('validated'))
    end)
end)

describe('The current_user endpoint', function()
    use_test_server()

    before_each(function()
        test_util.clean_db()
    end)

    it('GET should return the correct metadata for logged in user', function()
        local session = test_util.create_session(username, api_password)

        local status, body, headers = session:request('/users/c', {
            method = 'GET',
            expect='json'
        })

        assert.same(200, status)
        assert.same(false, body.isadmin)
        assert.same(true, body.verified)
        assert.same(username, body.username)
    end)
end)

describe('The user endpoint', function()
    use_test_server()

    before_each(function()
        test_util.clean_db()
    end)

    it('GET should return info for the logged in user', function()
        local session = test_util.create_session(username, api_password)

        local status, body, headers = session:request('/users/' .. username, {
            method = 'GET',
            expect='json'
        })

        assert.same(200, status)
        assert.same(false, body.isadmin)
        assert.same(username, body.username)
        assert.same(username .. '@snap.berkeley.edu', body.email)
    end)

    it('GET should return an error when the user is not logged in', function()
        test_util.create_user(username, api_password)

        local status, body, headers = request('/users/' .. username, {
            method = 'GET',
            expect='json'
        })

        assert.same(403, status)
        assert.is.truthy(body.errors[1]:find('do not have permission'))
    end)

    --[[ IN_DEV waiting on pr to be merged so that use is queried before delete is attempted

    it('an admin can DELETE a user', function()
        test_util.create_user(username, api_password)
        test_util.create_user(admin_user, admin_password, {isadmin = true})

        local session = test_util.create_session(admin_user, admin_password)

        local status, body, headers = session:request('/users/' .. username, {
            method = 'DELETE',
            expect='json'
        })

        assert.same(200, status)
        assert.is.truthy(body.message:find(username) and body.message:find('removed'))
        assert.is_nil(test_util.retrieve_user(username))
    end)

    ]]

    it('a basic user cannot DELETE a user', function()
        local second_u = username .. '_two'
        test_util.create_user(second_u, api_password)
        local session = test_util.create_session(username, api_password)

        local status, body, headers = session:request('/users/' .. second_u, {
            method = 'DELETE',
            expect = 'json'
        })

        assert.same(403, status)
        assert.is.truthy(body.errors[1]:find('do not have permission'))
    end)
end)

describe('The newpassword endpoint', function()
    local new_api_password = test_util.hash_for_api('updated_password_123456')

    use_test_server()

    before_each(function()
        test_util.clean_db()
    end)

    local update_password = function(session, old, new)
        return session:request('/users/' .. username .. '/newpassword', {
            method = 'POST',
            expect = 'json',
            data = {
                oldpassword = old,
                password_repeat = new,
                newpassword = new
            }
        })
    end

    it ('allows a logged in user to set a new password', function()
        local session = test_util.create_session(username, api_password)

        local status, body, headers = update_password(session, api_password, new_api_password)

        assert.same(200, status)
        assert.is.truthy(body.message:find('updated'))
    end)

    it('allows a user to log in with an updated password', function()
        local session = test_util.create_session(username, api_password)

        update_password(session, api_password, new_api_password)

        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = new_api_password,
            expect='json'
        })

        assert.same(200, status)
        assert.is.truthy(body.message:find(username))
    end)

    it('does not allow a user to log in with an old password', function()
        local session = test_util.create_session(username, api_password)

        update_password(session, api_password, new_api_password)

        local status, body, headers = request('/users/' .. username .. '/login', {
            method = 'POST',
            data = api_password,
            expect='json'
        })

        assert.same(400, status)
        assert.is.truthy(body.errors[1]:find('wrong password'))
    end)

    it('returns an error for a null new password', function()
        local session = test_util.create_session(username, api_password)

        local status, body, headers = update_password(session, api_password, nil)

        assert.same(400, status)
        print(body.errors[1])
        assert.is.truthy(body.errors[1]:find('newpassword'))
    end)

    -- NOTE: sending a nil oldpassword causes an app exception with an NPE in hash_password
end)
