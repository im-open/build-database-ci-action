# build-database-ci-action

This action uses [Flyway](https://flywaydb.org/) to spin up the specified database, run your migration scripts against it, and run your tests.

## Inputs
| Parameter                 | Is Required  | Description           |
| --------------------------|--------------|-----------------------|
| `db-server-name`          | true         | The name of the database server to build the database on. |
| `db-name`                 | true         | The name of the database to build. |
| `additional-build-params` | false        | A string containing any additional build parameters that will be tacked on to the end of the powershell run command. The other available parameters are the switch `incremental`, to prevent the dropping of the database before building, and the switch `runTests`. |

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
          additional-build-params: -runTests -incremental
```


## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).
