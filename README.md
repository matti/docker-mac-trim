# docker-mac-trim

Trims Docker.qcow2 file size.

## Install

```
bundle install
```

## Usage

```
# first remove all (or just not needed) containers:
docker ps -a --format "{{.ID}}" | xargs docker stop | xargs docker rm

# then remove all (or just not needed) images
docker images -a --format "{{.ID}}" | xargs docker rmi -f

# Then run the script
ruby trim.rb
```

For the best result you need to fill the entire 64GB (this will take ~64GB space during the script run).

The script also takes an argument:

```
ruby trim.rb 64
```
