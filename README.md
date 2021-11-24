# build-database-ci-action

This action uses [Flyway](https://flywaydb.org/) to spin up the specified database, run your migration scripts against it, and run your [tSQLt](https://tsqlt.org/) tests. 

## Index

- [Inputs](#inputs)
- [Example](#example)
- [Contributing](#contributing)
  - [Incrementing the Version](#incrementing-the-version)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Inputs
| Parameter                       | Is Required | Default | Description                                                                                                                                                                                                   |
| ------------------------------- | ----------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `db-server-name`                | true        | N/A     | The name of the database server to build the database on.                                                                                                                                                     |
| `db-server-port`                | false       | 1433    | The port that the database server listens on.                                                                                                                                                                 |
| `db-name`                       | true        | N/A     | The name of the database to build.                                                                                                                                                                            |
| `install-mock-db-objects`       | false       | false   | Specifies whether mock db objects should be used to fill out dependencies. If set to true mock-db-object-nuget-feed-url must also be set, otherwise an error will occur. The expected value is true or false. |
| `mock-db-object-nuget-feed-url` | false       | N/A     | The url to the nuget feed containing the mock database objects. This needs to be set if the install-mock-db-objects flag is set to avoid errors.                                                              |
| `nuget-username`                | false       | N/A     | The username for the user to authenticate with the nuget feed. This should be set if install-mock-db-objects is true.                                                                                         |
| `nuget-password`                | false       | N/A     | The password for the user to authenticate with the nuget feed. This should be set if install-mock-db-objects is true.                                                                                         |
| `incremental`                   | false       | false   | Specifies whether to drop and recreate the database before building, or apply to the current database. The expected value is true or false.                                                                   |
| `run-tests`                     | false       | false   | Specifies whether or not to run tSQLt tests.                                                                                                                                                                  |
| `drop-db-after-build`           | false       | true    | Specifies whether or not to drop the database after building. Set this to false if other steps in the job rely on the database existing.                                                                      |
| `should-validate-migrations`    | true        | false   | Determines whether flyway will validate the migration scripts before running them.                                                                                                                            |
| `seed-data`                     | false       | false   | A switch specifying whether or not to seed data into the database.                                                                                                                                            |
| `db-username`                   | false       | N/A     | The username to log into the database with. If not set, then integrated security will be used.                                                                                                                |
| `db-password`                   | false       | N/A     | The password associated with the db-username used for login.                                                                                                                                                  |

## Example

```yml
jobs:
  build-database:
    runs-on: [self-hosted, ubuntu-20.04]
    steps:
      - uses: actions/checkout@v2

      - name: Install Flyway
        uses: im-open/setup-flyway@v1.0.1
        with:
          version: 7.2.0

      - name: Build Database
        uses: im-open/build-database-ci-action@v2.0.1
        with:
          db-server-name: localhost
          db-name: MyLocalDB
          install-mock-db-objects: true
          mock-db-object-nuget-feed-url: https://www.nuget.org/
          nuget-username: NugetUsername
          nuget-password: ${{ secrets.NugetPassword }}
          incremental: false
          run-tests: true
          drop-db-after-build: false
          should-validate-migrations: false
          db-username: sa
          db-password: ${{ secrets.DB_PASSWORD }}
```


## Contributing

When creating new PRs please ensure:
1. For major or minor changes, at least one of the commit messages contains the appropriate `+semver:` keywords listed under [Incrementing the Version](#incrementing-the-version).
2. The `README.md` example has been updated with the new version.  See [Incrementing the Version](#incrementing-the-version).
3. The action code does not contain sensitive information.

### Incrementing the Version

This action uses [git-version-lite] to examine commit messages to determine whether to perform a major, minor or patch increment on merge.  The following table provides the fragment that should be included in a commit message to active different increment strategies.
| Increment Type | Commit Message Fragment                     |
| -------------- | ------------------------------------------- |
| major          | +semver:breaking                            |
| major          | +semver:major                               |
| minor          | +semver:feature                             |
| minor          | +semver:minor                               |
| patch          | *default increment type, no comment needed* |

## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).

[git-version-lite]: https://github.com/im-open/git-version-lite
