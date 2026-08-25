# Privacy

Whirl is designed to work locally on the Mac where it is installed.

## Data Whirl handles

Whirl reads installed-application metadata so it can display apps that may be assigned to shortcuts. It stores shortcut assignments, application preferences, and first-run completion state in the current user's local `UserDefaults` domain.

When Accessibility access is granted, Whirl may read window titles and application window metadata in order to display and activate windows or compatible app tabs. This information is used in memory for the requested interaction and is not persisted by Whirl.

## Data Whirl does not collect

The application contains no analytics, advertising SDK, crash-reporting service, account system, or network client code. Whirl does not transmit settings, application metadata, window metadata, or usage information to the developer or to a third party.

## Permissions

- **Accessibility:** Used only for enumerating, focusing, or switching windows and compatible app tabs.
- **Input Monitoring:** Not required.

This statement describes the official source code in this repository. A future change that alters data handling must update this document in the same pull request.
