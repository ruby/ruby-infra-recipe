# Athena is how anything older than the index retention gets queried. The
# archive is the only copy at that point, and rehydrating it back into Datadog
# re-indexes, which this org's contract limits the same way it limits retention.
resource "aws_glue_catalog_database" "logs" {
  name = "ruby_lang_logs"
}

resource "aws_glue_catalog_table" "fastly" {
  name          = "fastly"
  database_name = aws_glue_catalog_database.logs.name
  table_type    = "EXTERNAL_TABLE"

  partition_keys {
    name = "dt"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "string"
  }

  parameters = {
    EXTERNAL = "TRUE"

    # Partition projection instead of a crawler. Datadog's layout is already
    # dt=<date>/hour=<hour>, so the partitions are computable and nothing has to
    # scan the bucket to discover them. Projecting a day that was never written
    # costs nothing, Athena just finds no objects.
    "projection.enabled"          = "true"
    "projection.dt.type"          = "date"
    "projection.dt.format"        = "yyyyMMdd"
    "projection.dt.range"         = "20260730,NOW"
    "projection.dt.interval"      = "1"
    "projection.dt.interval.unit" = "DAYS"
    "projection.hour.type"        = "integer"
    "projection.hour.range"       = "0,23"
    "projection.hour.digits"      = "2"
    "storage.location.template"   = "s3://${aws_s3_bucket.log_archive.id}/fastly/dt=$${dt}/hour=$${hour}"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.log_archive.id}/fastly/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"

      parameters = {
        # `date` is a Hive type name and would need backticks in every query.
        "mapping.log_date" = "date"

        # A stray non-JSON object under the prefix yields null rows instead of
        # failing the whole query. Datadog wrote such a file once, when
        # partitioning_attributes was still set.
        "ignore.malformed.json" = "true"
      }
    }

    # Only the fields worth querying. The SerDe ignores the rest, so the other 40
    # odd attributes Datadog ships need no declaration until something needs one.
    columns {
      name = "log_date"
      type = "string"
    }

    columns {
      name = "service"
      type = "string"
    }

    columns {
      name = "host"
      type = "string"
    }

    columns {
      name = "status"
      type = "string"
    }

    columns {
      name = "attributes"
      type = "struct<http:struct<method:string,url:string,status_code:string,useragent:string,referer:string,request_time_ms:bigint,url_details:struct<path:string>>,network:struct<bytes_written:bigint,bytes_read:bigint,client:struct<ip:string,name:string,number:string>,geoip:struct<geo_country_code:string,geo_city:string>>,is_cacheable:boolean,server_datacenter:string,origin_host:string>"
    }
  }
}

resource "aws_athena_workgroup" "logs" {
  name = "ruby-lang-logs"

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.log_archive.id}/athena-results/"
    }
  }
}
