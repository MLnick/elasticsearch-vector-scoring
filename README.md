# Vector Scoring Plugin for Elasticsearch

This plugin allows you to score documents based on arbitrary raw vectors, 
using dot product or cosine similarity.

### Releases

Master branch targets Elasticsearch 5.4. **Not that version 5.5+ is _not_ supported as Elasticsearch changed their plugin mechanism**. An update for 5.5+ will be developed soon (PRs welcome).

[Branch es-2.4](https://github.com/MLnick/elasticsearch-vector-scoring/tree/es-2.4) targets Elasticsearch 2.4.x

## Overview

The aim of this plugin is to enable real-time scoring of vector-based 
models, in particular factor-based recommendation models.

In this case, user and item factor vectors are indexed using 
the [Delimited Payload Token Filter](https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis-delimited-payload-tokenfilter.html), 
e.g. the vector `[1.2, 0.1, 0.4, -0.2, 0.3]` is indexed as a string: 
`0|1.2 1|0.1 2|0.4 3|-0.2 4|0.3`.

This stores the vector indices as "terms" and the vector values as 
"payloads".

## Scoring

This plugin provides a native script `payload_vector_score` for use 
in `function_score` queries.

The script computes the dot product between the query vector and the 
document vector. In pseudo-code:

```java
for (i : vector_indices_terms) {
    payload = indexTermField(i).getPayload()
    score += payload * queryVector(i)
}
```

## Plugin installation

Targets Elasticsearch `5.4.0` and Java `1.8`.

### Simple installation

`ELASTIC_HOME/bin/elasticsearch-plugin install https://github.com/MLnick/elasticsearch-vector-scoring/releases/download/v5.4.0/elasticsearch-vector-scoring-5.4.0.zip`

### Build from source

1. Build: `mvn package`
2. Install plugin in Elasticsearch: `ELASTIC_HOME/bin/elasticsearch-plugin install file:///PROJECT_HOME/target/releases/elasticsearch-vector-scoring-5.4.0.zip` (stop ES first).


Start Elasticsearch: `ELASTIC_HOME/bin/elasticsearch`. You should see the plugin registered at Elasticsearch startup:
```
...
[2017-03-29T13:46:57,804][INFO ][o.e.p.PluginsService     ] [2Zs8kW3] loaded plugin [elasticsearch-vector-scoring]
...
```

## Example usage

### Index setup

```sh
curl -s -XPUT 'http://localhost:9200/test?pretty' -d '{
    "settings" : {
        "analysis": {
                "analyzer": {
                   "payload_analyzer": {
                      "type": "custom",
                      "tokenizer":"whitespace",
                      "filter":"delimited_payload_filter"
                    }
          }
        }
     }
}'

curl -s -XPUT 'http://localhost:9200/test/_mapping/movies?pretty' -d '
{
    "movies" : {
        "properties" : {
            "@model_factor": {
                            "type": "text",
                            "term_vector": "with_positions_offsets_payloads",
                            "analyzer" : "payload_analyzer"
                     }
        }
    }
}'

curl -s -XPUT 'http://localhost:9200/test/movies/1?pretty' -d '
{
    "@model_factor":"0|1.2 1|0.1 2|0.4 3|-0.2 4|0.3",
    "name": "Test 1"
}'

curl -s -XPUT 'http://localhost:9200/test/movies/2?pretty' -d '
{
    "@model_factor":"0|0.1 1|2.3 2|-1.6 3|0.7 4|-1.3",
    "name": "Test 2"
}'

curl -s -XPUT 'http://localhost:9200/test/movies/3?pretty' -d '
{
    "@model_factor":"0|-0.5 1|1.6 2|1.1 3|0.9 4|0.7",
    "name": "Test 3"
}'

curl -s -XGET 'http://localhost:9200/test/movies/1/_termvector?pretty' -d '
{
  "fields" : ["@model_factor"],
  "payloads" : true,
  "positions" : true
}'
```

### Scoring example

```sh
curl -s -XPOST 'http://localhost:9200/test/movies/_search?pretty' -d '
{
    "query": {
        "function_score": {
            "query" : {
                "query_string": {
                    "query": "*"
                }
            },
            "script_score": {
                "script": {
                	"inline": "payload_vector_score",
                	"lang": "native",
                	"params": {
                    	"field": "@model_factor",
                    	"vector": [0.1,2.3,-1.6,0.7,-1.3],
                    	"cosine" : true
                    }
				}
            },
            "boost_mode": "replace"
        }
    }
}'
```

This query returns results sorted by cosine similarity (including the document
itself). For "similar item" style recommendations, you can filter the 
query item from the returned results.

```
{
  "took" : 3,
  "timed_out" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "failed" : 0
  },
  "hits" : {
    "total" : 3,
    "max_score" : 0.99999994,
    "hits" : [ {
      "_index" : "test",
      "_type" : "movies",
      "_id" : "2",
      "_score" : 0.99999994,
      "_source" : {
        "@model_factor" : "0|0.1 1|2.3 2|-1.6 3|0.7 4|-1.3",
        "name" : "Test 2"
      }
    }, {
      "_index" : "test",
      "_type" : "movies",
      "_id" : "3",
      "_score" : 0.2175577,
      "_source" : {
        "@model_factor" : "0|-0.5 1|1.6 2|1.1 3|0.9 4|0.7",
        "name" : "Test 3"
      }
    }, {
      "_index" : "test",
      "_type" : "movies",
      "_id" : "1",
      "_score" : -0.19618797,
      "_source" : {
        "@model_factor" : "0|1.2 1|0.1 2|0.4 3|-0.2 4|0.3",
        "name" : "Test 1"
      }
    } ]
  }
}
```

## TODO

1. Tests
