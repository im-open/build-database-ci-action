# build-database-ci-action

This action uses [Flyway](https://flywaydb.org/) to spin up the specified database, run your migration scripts against it, and run your [tSQLt](https://tsqlt.org/) tests.

## Inputs
| Parameter                       | Is Required  | Default | Description  |
| --------------------------------|--------------|---------|--------------|
| `db-server-name`                | true         | N/A     |The name of the database server to build the database on. |
| `db-name`                       | true         | N/A     |The name of the database to build. |
| `install-mock-db-objects`       | false        | false   |Specifies whether mock db objects should be used to fill out dependencies. |
| `mock-db-object-nuget-feed-url` | false        | N/A     |The url to the nuget feed containing the mock database objects. This should be set if the install-mock-db-objects flag is set. |
| `incremental`                   | false        | false   |Specifies whether to drop and recreate the database before building, or apply to the current database. |
| `run-tests`                     | false        | false   |Specifies whether or not to run tSQLt tests. |

## Example

```yml
jobs:
  build-database:
    runs-on: [self-hosted, windows-2019]
    steps:
      - uses: actions/checkout@v2

      - name: Install Flyway
        uses: im-open/setup-flyway@v1.0.0
        with:
          version: 7.2.0

      - name: Build Database
        uses: im-open/build-database-ci-action@v1.0.0
        with:
          db-server-name: localhost
          db-name: MyLocalDB
          install-mock-db-objects: true
          mock-db-object-nuget-feed-url: https://www.nuget.org/
          incremental: false
          run-tests: true
```


## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).
