# build-database-ci-action

This action uses [Flyway](https://flywaydb.org/) to spin up the specified database, run your migration scripts against it, and run your [tSQLt](https://tsqlt.org/) tests.

## Index

- [build-database-ci-action](#build-database-ci-action)
  - [Index](#index)
  - [Inputs](#inputs)
  - [Example](#example)
  - [Contributing](#contributing)
    - [Incrementing the Version](#incrementing-the-version)
  - [Code of Conduct](#code-of-conduct)
  - [License](#license)

## Inputs

| Parameter                        | Is Required | Default | Description                                                                                                                                                                                                                                                                                                                        |
| -------------------------------- | ----------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `db-server-name`                 | true        | N/A     | The name of the database server to build the database on.                                                                                                                                                                                                                                                                          |
| `db-server-port`                 | false       | 1433    | The port that the database server listens on.                                                                                                                                                                                                                                                                                      |
| `db-name`                        | true        | N/A     | The name of the database to build.                                                                                                                                                                                                                                                                                                 |
| `use-integrated-security`        | false       | false   | Use domain integrated security. This only works on windows. If running on a linux runner, set this to false or don't specify a value. If false, a db-username and db-password should be specified; if they aren't then the action will attempt to use integrated security. If true, those parameters will be ignored if specified. |
| `db-username`                    | false       | N/A     | The username to log into the database with. If not set, then integrated security will be used.                                                                                                                                                                                                                                     |
| `db-password`                    | false       | N/A     | The password associated with the db-username used for login.                                                                                                                                                                                                                                                                       |
| `migration-files-path`           | true        | N/A     | The path to the base directory containing the migration files to process with flyway.                                                                                                                                                                                                                                              |
| `install-mock-db-objects`        | false       | false   | Specifies whether mock db objects should be used to fill out dependencies. If set to true mock-db-object-nuget-feed-url must also be set, otherwise an error will occur. The expected value is true or false.                                                                                                                      |
| `mock-db-object-dependency-list` | false       | N/A     | A json string containing a list of objects with the name of the dependency package, the version, and the url where the package is stored.                                                                                                                                                                                          |
| `incremental`                    | false       | false   | Specifies whether to drop and recreate the database before building, or apply to the current database. The expected value is true or false. If true, the create-database-file property will not be used.                                                                                                                           |
| `create-database-file`           | false       | N/A     | The file path to the sql file that initializes the database. This script will only be run if the incremental property is false.                                                                                                                                                                                                    |
| `run-tests`                      | false       | false   | Specifies whether or not to run tests. The expected values are true and false. If true, test-files-path should also be set. If false, test-files-path will be ignored.                                                                                                                                                             |
| `test-files-path`                | false       | N/A     | The path to the files with tSQLt tests.                                                                                                                                                                                                                                                                                            |
| `test-timeout`                   | false       | 300     | An optional setting for the allowed wait time, in seconds, for the tests to execute. If tests sometimes hang, or shouldn't take longer than a certain amount of time, this parameter can be helpful.                                                                                                                               |
| `drop-db-after-build`            | false       | false   | Specifies whether or not to drop the database after building. Set this to false if other steps in the job rely on the database existing.                                                                                                                                                                                           |
| `should-validate-migrations`     | true        | false   | Determines whether flyway will validate the migration scripts before running them.                                                                                                                                                                                                                                                 |
| `seed-data`                      | false       | false   | A switch specifying whether or not to seed data into the database.                                                                                                                                                                                                                                                                 |
| `seed-data-files-path`           | false       | N/A     | The path to the files with seeding database.                                                                                                                                                                                                                                                                                       |
| `managed-schemas`                | true        | dbo     | A comma separated list of schemas that are to be managed by flyway.                                                                                                                                                                                                                                                                |

The `mock-db-object-dependency-list` should be a json array of objects with the following properties:

```json
{
  "version": "1.0.0",
  "packageName": "some_package",
  "nugetUrl": "https://www.some-nuget-repo.com"
}
```

## Example

```yml
jobs:
  build-database:
    runs-on: [self-hosted, ubuntu-20.04]
    steps:
      - uses: actions/checkout@v3

      - name: Install Flyway
        uses: im-open/setup-flyway@v1.1.0
        with:
          version: 7.2.0

      - name: Build Database
        uses: im-open/build-database-ci-action@v3.0.3
        with:
          db-server-name: localhost
          db-server-port: 1433
          db-name: MyLocalDB
          use-integrated-security: false
          db-username: sa
          db-password: ${{ secrets.DB_PASSWORD }}
          migration-files-path: ./path/to/migrations
          install-mock-db-objects: true
          mock-db-object-dependency-list: '[{"version":"1.0.0","packageName":"dbo.Something","nugetUrl":"https://nuget.pkg.github.com/my-org/my-repo/dbo.Something.nupkg"},{"version":"1.2.0","packageName":"dbo.SomeOtherThing","nugetUrl":"https://nuget.pkg.github.com/my-org/my-repo/dbo.SomeOtherThing.nupkg"}]'
          incremental: false
          create-database-file: ./path/to/create-db.sql
          run-tests: true
          test-files-path: ./path/to/tsqlt/tests
          test-timeout: 120 # 2 minutes
          drop-db-after-build: false
          should-validate-migrations: false
          seed-data: true
          seed-data-files-path: ./path/to/seed/data/files
          managed-schemas: dbo,MyCustomSchema,AnotherSchema
```

## Contributing

When creating new PRs please ensure:

1. For major or minor changes, at least one of the commit messages contains the appropriate `+semver:` keywords listed under [Incrementing the Version](#incrementing-the-version).
2. The `README.md` example has been updated with the new version. See [Incrementing the Version](#incrementing-the-version).
3. The action code does not contain sensitive information.

### Incrementing the Version

This action uses [git-version-lite] to examine commit messages to determine whether to perform a major, minor or patch increment on merge. The following table provides the fragment that should be included in a commit message to active different increment strategies.
| Increment Type | Commit Message Fragment |
| -------------- | ------------------------------------------- |
| major | +semver:breaking |
| major | +semver:major |
| minor | +semver:feature |
| minor | +semver:minor |
| patch | _default increment type, no comment needed_ |

## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).

[git-version-lite]: https://github.com/im-open/git-version-lite
