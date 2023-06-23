# build-database-ci-action

This action uses [Flyway](https://flywaydb.org/) to spin up the specified database, run your migration scripts against it, and run your [tSQLt](https://tsqlt.org/) tests.

## Index

- [build-database-ci-action](#build-database-ci-action)
  - [Index](#index)
  - [Inputs](#inputs)
  - [Examples](#examples)
  - [Contributing](#contributing)
    - [Incrementing the Version](#incrementing-the-version)
  - [Code of Conduct](#code-of-conduct)
  - [License](#license)

## Inputs

| Parameter                        | Is Required                                                                                | Default | Description                                                                                                                                                                                                                                                                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `db-server-name`                 | **Yes**                                                                                    | N/A     | The name of the database server to build the database on.                                                                                                                                                                                                                                                                          |
| `db-server-port`                 | **No**                                                                                     | 1433    | The port that the database server listens on.                                                                                                                                                                                                                                                                                      |
| `db-name`                        | **Yes**                                                                                    | N/A     | The name of the database to build.                                                                                                                                                                                                                                                                                                 |
| `use-integrated-security`        | **No**                                                                                     | false   | Use domain integrated security. This only works on windows. If running on a linux runner, set this to false or don't specify a value. If false, a db-username and db-password should be specified; if they aren't then the action will attempt to use integrated security. If true, those parameters will be ignored if specified. |
| `trust-server-certificate`       | **No**                                                                                     | false   | Trust Server Certificate parameter will be added to sqlcmd connections strings.  Set to true when certificate for server is self signed.                                                                                                                                                                                           |
| `db-username`                    | **No**: if `use-integrated-security: false`<br>**Yes**: if `use-integrated-security: true` | N/A     | The username to log into the database with. If not set, then integrated security will be used.                                                                                                                                                                                                                                     |
| `db-password`                    | **No**: if `use-integrated-security: false`<br>**Yes**: if `use-integrated-security: true` | N/A     | The password associated with the db-username used for login.                                                                                                                                                                                                                                                                       |
| `migration-files-path`           | **Yes**                                                                                    | N/A     | The path to the base directory containing the migration files to process with flyway. Can be a comma separated list of directories.                                                                                                                                                                                                |
| `install-mock-db-objects`        | **No**                                                                                     | false   | Specifies whether mock db objects should be used to fill out dependencies. If set to true mock-db-object-nuget-feed-url must also be set, otherwise an error will occur. The expected value is true or false.                                                                                                                      |
| `mock-db-object-dependency-list` | **No**                                                                                     | N/A     | A json string containing a list of objects with the name of the dependency package, the version, the url where the package is stored, and optionally a bearer token for authentication.                                                                                                                                            |
| `incremental`                    | **No**                                                                                     | false   | Specifies whether to drop and recreate the database before building, or apply to the current database. The expected value is true or false. If true, the create-database-file property will not be used.                                                                                                                           |
| `create-database-file`           | **No**: if `incremental: true`<br>**Yes**: if `incremental: false`                         | N/A     | The file path to the sql file that initializes the database. This script will only be run if the incremental property is false.                                                                                                                                                                                                    |
| `run-tests`                      | **No**                                                                                     | false   | Specifies whether or not to run tests. The expected values are true and false. If true, test-files-path should also be set. If false, test-files-path will be ignored.                                                                                                                                                             |
| `test-files-path`                | **No**: if `run-tests: false`<br>**Yes**: if `run-tests: true`                             | N/A     | The path to the files with tSQLt tests.                                                                                                                                                                                                                                                                                            |
| `test-timeout`                   | **No**                                                                                     | 300     | An optional setting for the allowed wait time, in seconds, for the tests to execute. If tests sometimes hang, or shouldn't take longer than a certain amount of time, this parameter can be helpful.                                                                                                                               |
| `drop-db-after-build`            | **No**                                                                                     | false   | Specifies whether or not to drop the database after building. Set this to false if other steps in the job rely on the database existing.                                                                                                                                                                                           |
| `should-validate-migrations`     | **No**                                                                                     | false   | Determines whether flyway will validate the migration scripts before running them.                                                                                                                                                                                                                                                 |
| `seed-data`                      | **No**                                                                                     | false   | A switch specifying whether or not to seed data into the database.                                                                                                                                                                                                                                                                 |
| `seed-data-files-path`           | **No**                                                                                     | N/A     | The path to the files with seeding database.                                                                                                                                                                                                                                                                                       |
| `managed-schemas`                | **No**                                                                                     | dbo     | A comma separated list of schemas that are to be managed by flyway.                                                                                                                                                                                                                                                                |

The `mock-db-object-dependency-list` should be a json array of objects with the following properties:

```json
{
  "version": "1.0.0",
  "packageName": "some_package",
  "nugetUrl": "https://www.some-nuget-repo.com",
  "authToken": "ghp_fdijlfdsakeizdkliejfezejw"
}
```

**Notes** 
* The `authToken` property is optionally used for nuget sources that require a bearer token, such as GitHub Packages. It should not be included if it is unnecessary.
* The `nugetUrl` for GitHub Packages can be pretty tricky to lookup, so for reference the pattern is as follows: `https://nuget.pkg.github.com/<owner>/download/<package-name>/<version>/<file-name>.nupkg`. Here's an example of how that could look if this repo were publishing a package called `MyDbObject`: `https://nuget.pkg.github.com/im-open/download/MyDbObject/1.0.0/MyDbObject.1.0.0.nupkg`.

## Examples

```yml
jobs:
  build-database:
    runs-on: [self-hosted, ubuntu-20.04]
    steps:
      - uses: actions/checkout@v3

      - name: Install Flyway
        uses: im-open/setup-flyway@v1
        with:
          version: 7.2.0

      - name: Build Database
        # You may also reference the major or major.minor version
        uses: im-open/build-database-ci-action@v3.2.4
        with:
          db-server-name: localhost
          db-server-port: 1433
          db-name: MyLocalDB
          use-integrated-security: false
          trust-server-certificate: true # Required on windows vm runners to be set to true
          db-username: sa
          db-password: ${{ secrets.DB_PASSWORD }}
          migration-files-path: ./path/to/migrations
          install-mock-db-objects: true
          mock-db-object-dependency-list: '[{"version":"1.0.0","packageName":"dbo.Something","nugetUrl":"https://nuget.pkg.github.com/my-org/download/Something/1.0.0/dbo.Something.1.0.0.nupkg","authToken":"ghp_dkfsjakldafl"},{"version":"1.2.0","packageName":"dbo.SomeOtherThing","nugetUrl":"https://nuget.pkg.github.com/my-org/download/SomeOtherThing/1.2.0/dbo.SomeOtherThing1.2.0.nupkg","authToken":"ghp_dkfsjakldafl"}]'
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

If your migration script are spread over multiple directories, and there isn't a common parent directory that can be used, multiple migration directories can be specified:

```yml
jobs:
  build-database:
    runs-on: [self-hosted, ubuntu-20.04]
    steps:
      - uses: actions/checkout@v3

      - name: Install Flyway
        uses: im-open/setup-flyway@v1
        with:
          version: 7.2.0

      - name: Build Database
        # You may also reference the major or major.minor version
        uses: im-open/build-database-ci-action@v3.2.4
        with:
          db-server-name: localhost
          db-server-port: 1433
          db-name: MyLocalDB
          migration-files-path: ./path/to/migrations,./another/path
```

## Contributing

When creating new PRs please ensure:

1. For major or minor changes, at least one of the commit messages contains the appropriate `+semver:` keywords listed under [Incrementing the Version](#incrementing-the-version).
1. The action code does not contain sensitive information.

When a pull request is created and there are changes to code-specific files and folders, the `auto-update-readme` workflow will run.  The workflow will update the action-examples in the README.md if they have not been updated manually by the PR author. The following files and folders contain action code and will trigger the automatic updates:

- `action.yml`
- `src/**`

There may be some instances where the bot does not have permission to push changes back to the branch though so this step should be done manually for those branches. See [Incrementing the Version](#incrementing-the-version) for more details.

### Incrementing the Version

The `auto-update-readme` and PR merge workflows will use the strategies below to determine what the next version will be.  If the `auto-update-readme` workflow was not able to automatically update the README.md action-examples with the next version, the README.md should be updated manually as part of the PR using that calculated version.

This action uses [git-version-lite] to examine commit messages to determine whether to perform a major, minor or patch increment on merge. The following table provides the fragment that should be included in a commit message to active different increment strategies.
| Increment Type | Commit Message Fragment                     |
| -------------- | ------------------------------------------- |
| major          | +semver:breaking                            |
| major          | +semver:major                               |
| minor          | +semver:feature                             |
| minor          | +semver:minor                               |
| patch          | _default increment type, no comment needed_ |

## Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).

[git-version-lite]: https://github.com/im-open/git-version-lite
