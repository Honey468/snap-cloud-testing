# snap-cloud-testing
Functional test suites for the snap cloud web application.

## Running the tests
If you haven't already create a user named `cloud` by issuing the following commands using the `psql` program:
```
> CREATE USER cloud WITH PASSWORD 'snap-cloud-password';
> ALTER ROLE cloud WITH LOGIN;
```
Then run `./run_tests.sh` from this directory. You may need to make the file executable.

## Adding New Tests
Add new test files under the `test` directory. The test runner will recursively search for and 
run any file that ends in `_test.lua` in that directory. You can also define test utility files in that directory.
The test runner includes the root of the `test` directory as a module search path so imports
need not prefix the path. See `api_test.lua`, which imports `test_util.lua` for an example.
