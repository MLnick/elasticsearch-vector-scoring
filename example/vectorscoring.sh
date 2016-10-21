#!/bin/sh

# Init an index with custom analyzer

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
                            "type": "string",
                            "term_vector": "with_positions_offsets_payloads",
                            "analyzer" : "payload_analyzer"
                     }
        }
    }
}
'

curl -s -XPUT 'http://localhost:9200/test/movies/1?pretty' -d '
{
    "@model_factor":"0|1.2 1|0.1 2|0.4 3|-0.2 4|0.3",
    "name": "Test 1"
}
'

curl -s -XPUT 'http://localhost:9200/test/movies/2?pretty' -d '
{
    "@model_factor":"0|0.1 1|2.3 2|-1.6 3|0.7 4|-1.3",
    "name": "Test 2"
}
'

curl -s -XPUT 'http://localhost:9200/test/movies/3?pretty' -d '
{
    "@model_factor":"0|-0.5 1|1.6 2|1.1 3|0.9 4|0.7",
    "name": "Test 3"
}
'

curl -s -XGET 'http://localhost:9200/test/movies/1/_termvector?pretty' -d '
{
  "fields" : ["@model_factor"],
  "payloads" : true,
  "positions" : true
}'

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
                "script": "payload_vector_score",
                "lang": "native",
                "params": {
                    "field": "@model_factor",
                    "vector": [0.1,2.3,-1.6,0.7,-1.3],
                    "cosine" : true
                }
            },
            "boost_mode": "replace"
        }
    }
}
'