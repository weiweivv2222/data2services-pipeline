docker run -dit --rm -p 8047:8047 -p 31010:31010 --name drill -v c:/data:/data:ro apache-drill
docker run -d --rm --name graphdb -p 7200:7200 -v c:/data/graphdb:/opt/graphdb/home -v /data/graphdb-import:/root/graphdb-import graphdb
