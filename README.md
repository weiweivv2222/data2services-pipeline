# Get started

This is a demonstrator ETL pipeline that **converts** relational databases, tabular files, and XML files **to RDF**. A generic RDF, based on the input data structure, is generated and [SPARQL](https://www.w3.org/TR/sparql11-query/) queries are **designed by the user** to map the generic RDF to a **specific model**.

* Only [Docker](https://docs.docker.com/install/) is required to run the pipeline. Checkout the [Wiki](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Docker-documentation) if you have issues with Docker installation.
* Following documentation **focuses on Linux & MacOS**.
* **Windows documentation** can be found [here](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-on-Windows).
* Modules are from the [Data2Services ecosystem](https://github.com/MaastrichtU-IDS/data2services-ecosystem). 

---

## The Data2Services philosophy

Containers run with a few parameters (input file path, SPARQL endpoint, credentials, mapping file path)

- **Build** the Docker images
- **Start services** that need to be running
- **Execute the containers** you want, providing the proper parameters

---

# Clone

```shell
git clone --recursive https://github.com/MaastrichtU-IDS/data2services-pipeline.git

cd data2services-pipeline

# To update all submodules
git submodule update --recursive --remote
```

---

# Build

`build.sh` is a convenience script to build all Docker images, but they can be built separately.

* You need to **download** [Apache Drill installation bundle](https://drill.apache.org/download/) and [GraphDB standalone zip](https://www.ontotext.com/products/graphdb/) (register to get an email with download URL). 
* Then **put** the `.tar.gz` and `.zip` files in the `./apache-drill` and `./graphdb` repositories.

```shell
# Download Apache Drill
curl http://apache.40b.nl/drill/drill-1.15.0/apache-drill-1.15.0.tar.gz -o apache-drill/apache-drill-1.15.0.tar.gz
# Build docker images (don't forget to get GraphDB zip file)
./build.sh
```

---

# Start services

In a production environment, it is considered that both [Apache Drill](https://drill.apache.org/download/) and [GraphDB](https://www.ontotext.com/products/graphdb/) services are present. Other RDF triple stores should also work, but have not been tested yet.

```shell
# Build and start apache-drill
docker build -t apache-drill ./apache-drill
docker run -dit --rm -p 8047:8047 -p 31010:31010 \
  --name drill -v /data:/data:ro \
  apache-drill
# Build and start graphdb
docker build -t graphdb ./graphdb
docker run -d --rm --name graphdb -p 7200:7200 \
  -v /data/graphdb:/opt/graphdb/home \
  -v /data/graphdb-import:/root/graphdb-import \
  graphdb
```

* For MacOS, make sure that access to the `/data` repository has been granted in Docker configuration.
* Check the [Wiki](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-using-docker-compose) to use `docker-compose` to run the 2 containers.

---

# Run using Docker commands

* Check the [Wiki](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Docker-documentation) for more detail on how to run Docker containers (sharing volumes, link between containers)
* The directory where are the **files to convert needs to be in `/data`** (to comply with [Apache Drill](https://drill.apache.org/download/) shared volume).
* In those examples we are using `/data/data2services` as working directory (containing all the files, note that it is usually shared as `/data` in the Docker containers).

## Download datasets

Source files can be set to be downloaded automatically using [Shell scripts](https://github.com/MaastrichtU-IDS/data2services-download/blob/master/datasets/TEMPLATE/download.sh). See the [data2services-download](https://github.com/MaastrichtU-IDS/data2services-download) module for more details.

```shell
docker pull vemonet/data2services-download
docker run -it --rm -v /data/data2services:/data \
  vemonet/data2services-download \
  --download-datasets drugbank,hgnc,date \
  --username my_login --password my_password \
  --clean # to delete all files in /data/data2services
```

---

## Convert XML

Use [xml2rdf](https://github.com/MaastrichtU-IDS/xml2rdf) to convert XML files to a generic RDF based on the file structure.

```shell
docker build -t xml2rdf ./xml2rdf
docker run --rm -it -v /data:/data \
  xml2rdf  \
  -i "/data/data2services/myfile.xml.gz" \
  -o "/data/data2services/myfile.nq.gz" \
  -g "https://w3id.org/data2services/graph/xml2rdf"
```

---

## Generate R2RML mapping file for TSV & RDB

We use [AutoR2RML](https://github.com/amalic/autor2rml) to generate the [R2RML](https://www.w3.org/TR/r2rml/) mapping file to convert relational databases (Postgres, SQLite, MariaDB), CSV, TSV and PSV files to a generic RDF representing the input data structure. See the [Wiki](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-AutoR2RML-with-various-DBMS) for other DBMS systems and how to [deploy databases](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-PostgreSQL-database).

```shell
docker build -t autor2rml ./AutoR2RML
# For CSV, TSV, PSV files
# Apache Drill needs to be running with the name 'drill'
docker run -it --rm --link drill:drill -v /data:/data \
  autor2rml \
  -j "jdbc:drill:drillbit=drill:31010" -r \
  -o "/data/data2services/mapping.trig" \
  -d "/data/data2services" \
  -b "https://w3id.org/data2services/" \
  -g "https://w3id.org/data2services/graph/autor2rml"
# For Postgres, a postgres docker container 
# needs to be running with the name 'postgres'
docker run -it --rm --link postgres:postgres -v /data:/data \
  autor2rml \
  -j "jdbc:postgresql://postgres:5432/my_database" -r \
  -o "/data/data2services/mapping.trig" \
  -u "postgres" -p "pwd" \
  -b "https://w3id.org/data2services/" \
  -g "https://w3id.org/data2services/graph/autor2rml"
```

---

## Use R2RML mapping file to generate RDF

Generate the generic RDF using [R2RML](https://github.com/amalic/r2rml) and the previously generated `mapping.trig` file. 

```shell
docker build -t r2rml ./r2rml
# Add config.properties file for R2RML in /data/data2services
connectionURL = jdbc:drill:drillbit=drill:31010
mappingFile = /data/mapping.trig
outputFile = /data/rdf_output.nq
format = NQUADS
# Run R2RML for Drill or Postgres
docker run -it --rm --link drill:drill \ # --link postgres:postgres
  -v /data/data2services:/data \
  r2rml /data/config.properties
```

---

## Upload RDF

Finally, use [RdfUpload](https://github.com/MaastrichtU-IDS/RdfUpload/) to upload the generated RDF to GraphDB. It can also be done manually using [GraphDB server imports](http://graphdb.ontotext.com/documentation/standard/loading-data-using-the-workbench.html#importing-server-files) for more efficiency on large files.

```shell
docker build -t rdf-upload ./RdfUpload
docker run -it --rm --link graphdb:graphdb -v /data/data2services:/data \
  rdf-upload \
  -m "HTTP" -if "/data" \
  -url "http://graphdb:7200" \
  -rep "test" \
  -un "import_user" -pw "PASSWORD"
```

---

## Transform generic RDF to target model

Last step is to transform the generic RDF generated a particular data model. See the [data2services-transform-repository](https://github.com/MaastrichtU-IDS/data2services-transform-repository) project for examples of transformation to the [BioLink model](https://biolink.github.io/biolink-model/docs/) using the [data2services-sparql-operations](https://github.com/MaastrichtU-IDS/data2services-sparql-operations) module to execute multiple SPARQL queries from a Github repository.

```shell
docker pull vemonet/data2services-sparql-operations

# Load UniProt organisms and Human proteins as BioLink in local endpoint
docker run -d --link graphdb:graphdb \
  vemonet/data2services-sparql-operations \
  -f "https://github.com/MaastrichtU-IDS/data2services-transform-repository/tree/master/sparql/insert-biolink/uniprot" \
  -ep "http://graphdb:7200/repositories/test/statements" \
  -un MYUSERNAME -pw MYPASSWORD \
  -var outputGraph:https://w3id.org/data2services/graph/biolink/uniprot

# Load DrugBank xml2rdf generic RDF as BioLink to remote SPARQL endpoint
docker run -d vemonet/data2services-sparql-operations \
  -f "https://github.com/MaastrichtU-IDS/data2services-transform-repository/tree/master/sparql/insert-biolink/drugbank" \
  -ep "http://graphdb.dumontierlab.com/repositories/ncats-red-kg/statements" \
  -un USERNAME -pw PASSWORD \
  -var serviceUrl:http://localhost:7200/repositories/test inputGraph:http://data2services/graph/xml2rdf/drugbank outputGraph:https://w3id.org/data2services/graph/biolink/drugbank
```

* You can find example of SPARQL queries used for conversion to RDF BioLink:
  * [UniProt](https://github.com/MaastrichtU-IDS/data2services-transform-repository/tree/master/sparql/insert-biolink/uniprot) (RDF)
  * [DrugBank](https://github.com/MaastrichtU-IDS/data2services-transform-repository/tree/master/sparql/insert-biolink/drugbank) (XML)
  * [HGNC](https://github.com/MaastrichtU-IDS/data2services-transform-repository/tree/master/sparql/insert-biolink/hgnc) (TSV through AutoR2RML)
* It is recommended to write **multiple SPARQL queries with simple goals** (get all drugs infos, get all drug-drug interactions, get gene infos), rather than one complex query addressing everything.
* Remove the `\` and make the `docker run` command one line for **Windows PowerShell**.

---

# Further documentation in the Wiki

* [Docker documentation](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Docker-documentation) (fix known issues, run, share volumes, link containers, network)
* [Run using docker-compose](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-using-docker-compose)
* [Run AutoR2RML with various DBMS](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-AutoR2RML-with-various-DBMS)
* [Fix CSV, TSV, PSV files without columns](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Fix-CSV,-TSV,-PSV-files-without-columns)
* [Run on Windows](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-on-Windows)
* [Run using convenience scripts](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-using-convenience-script)
* [Run Postgres](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-PostgreSQL)
* [Run MariaDB](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Run-MariaDB)
* [Secure GraphDB](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/Secure-GraphDB:-create-users)
* `BETA`: [RDF validation using ShEx](https://github.com/MaastrichtU-IDS/data2services-pipeline/wiki/RDF-validation-using-ShEx)

---

# Citing this work

If you use Data2Services in a scientific publication, you are highly encouraged (not required) to cite the following paper:

**Data2Services: enabling automated conversion of data to services.** *Vincent Emonet, Alexander Malic, Amrapali Zaveri, Andreea Grigoriu and Michel Dumontier.*

Bibtex entry:

```tex
@inproceedings{Emonet2018,
author = {Emonet, Vincent and Malic, Alexander and Zaveri, Amrapali and Grigoriu, Andreea and Dumontier, Michel},
title = {Data2Services: enabling automated conversion of data to services},
booktitle = {11th Semantic Web Applications and Tools for Healthcare and Life Sciences},
year = {2018}
}
```

