## Migrate helm repositories

### Required Packages

- bash
- curl
- jq

### Docs

Change run.sh, add Source & Destination Nexus connection parameters

```
nexusSourceHost="https://source.nexus"
nexusSourceId="admin"
nexusSourcePass="admin123"
nexusDestHost="https://destination.nexus"
nexusDestId="admin"
nexusDestPass="admin123"
```

### Run

```
$ ./run.sh
```
