# How integration tests are written

I'm using my own way of writing integration tests.

The following instructions should help you write more tests

- Each group of tests should be in a file written as a class that extends `IntegrationTestBase` in `base.dart`
- Each group class must have the following property denoting the group name: `String get name => 'groupTitle';`
- Write tests as a map with keys being the test name, and the value as an async function (test body)
- Each test name should begin with a number in the following format: `01`
- Each test name can end with:
    - `++` indicating that its an important test (Important for the following tests to work)
    - `--` indicating that its a skipped test (would run only if we're thoroughly testing)
    - If it doesn't end with neither those then it is a regular test.
- Reference the tests in the `integration.dart` file like this: `await doctorsPageIntegrationTest(tester: tester).run();`
- Run the tests in the terminal using the following command:
    - `flutter test integration_test/integration.dart -d windows`
- Run the integration in watch mode: `dart integration_test/watch.dart` (Tested on windows, might need a bit of adjustments)
- Run all tests in `all` mode (include skipped -- tests): `dart integration_test/watch.dart --all`
- Run all tests in `regular` mode (skip skipped -- tests): `dart integration_test/watch.dart`
- Run all tests in `onlyRequired` mode (include only required ++ tests): `dart integration_test/watch.dart --onlyRequired`
- Run specific group (all tests for specific group, but important only for others): `dart integration_test/watch.dart doctors`

You may run into unknown errors while running the test in `--all` mode. it's best to run them sequentially:

```bash
dart integration_test/watch.dart login;
dart integration_test/watch.dart doctors;
dart integration_test/watch.dart patients;
dart integration_test/watch.dart appointments;
dart integration_test/watch.dart calendar;
dart integration_test/watch.dart labworks;
dart integration_test/watch.dart settings;
```


### Why my own way?

I don't know! I guess I didn't like the convention of how its done. Though I like flutter in general.

Cheers!

Ali A. Saleem
3/12/2024 1:26 AM