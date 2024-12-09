# usage
1. download: [application url](https://github.com/PetScreeningInc/devops-tools/releases/download/v0.0.1/ps-cmdr.app.zip) 
2. open a terminal and run:
```bash
xattr -cr /path/to/ps-cmdr.app
```
3. run app -> click install tools -> provide password if prompted

# building
```bash
 go build main.go
```

# packaging
```bash
 ~/go/bin/fyne package -os darwin
```

