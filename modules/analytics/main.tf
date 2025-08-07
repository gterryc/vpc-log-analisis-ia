# Glue Database
resource "aws_glue_catalog_database" "vpc_flow_logs" {
  name        = "${var.project_name}_flow_logs_db"
  description = "Database for VPC Flow Logs analysis"
  
  parameters = {
    "classification" = "parquet"
  }
}

# Glue Table para VPC Flow Logs
resource "aws_glue_catalog_table" "vpc_flow_logs" {
  name          = "vpc_flow_logs"
  database_name = aws_glue_catalog_database.vpc_flow_logs.name
  
  table_type = "EXTERNAL_TABLE"
  
  parameters = {
    "classification"                = "parquet"
    "compressionType"               = "gzip"
    "typeOfData"                   = "file"
    "projection.enabled"           = "true"
    "projection.year.type"         = "integer"
    "projection.year.range"        = "2020,2030"
    "projection.month.type"        = "integer" 
    "projection.month.range"       = "1,12"
    "projection.month.digits"      = "2"
    "projection.day.type"          = "integer"
    "projection.day.range"         = "1,31"
    "projection.day.digits"        = "2"
    "projection.hour.type"         = "integer"
    "projection.hour.range"        = "0,23"
    "projection.hour.digits"       = "2"
    "storage.location.template"    = "s3://${var.bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${data.aws_region.current.name}/$${year}/$${month}/$${day}/"
  }
  
  storage_descriptor {
    location      = "s3://${var.bucket_name}/AWSLogs/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }
    
    columns {
      name = "version"
      type = "int"
    }
    
    columns {
      name = "account_id"
      type = "string"
    }
    
    columns {
      name = "interface_id"
      type = "string"
    }
    
    columns {
      name = "srcaddr"
      type = "string"
    }
    
    columns {
      name = "dstaddr"
      type = "string"
    }
    
    columns {
      name = "srcport"
      type = "int"
    }
    
    columns {
      name = "dstport"
      type = "int"
    }
    
    columns {
      name = "protocol"
      type = "int"
    }
    
    columns {
      name = "packets"
      type = "bigint"
    }
    
    columns {
      name = "bytes"
      type = "bigint"
    }
    
    columns {
      name = "windowstart"
      type = "bigint"
    }
    
    columns {
      name = "windowend"
      type = "bigint"
    }
    
    columns {
      name = "action"
      type = "string"
    }
    
    columns {
      name = "flowlogstatus"
      type = "string"
    }
  }
  
  partition_keys {
    name = "year"
    type = "string"
  }
  
  partition_keys {
    name = "month"
    type = "string"
  }
  
  partition_keys {
    name = "day"
    type = "string"
  }
  
  partition_keys {
    name = "hour"
    type = "string"
  }
}

# Workgroup de Athena
resource "aws_athena_workgroup" "anomaly_detection" {
  name = "${var.project_name}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.bucket_name}-athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    bytes_scanned_cutoff_per_query = 1073741824 # 1GB limit
  }

  tags = var.tags
}

# Named Queries para detección de anomalías
resource "aws_athena_named_query" "port_scanning_detection" {
  name        = "port_scanning_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect port scanning activities"

  query = <<EOF
SELECT 
    srcaddr,
    COUNT(DISTINCT dstport) as unique_ports,
    COUNT(*) as total_attempts,
    MIN(from_unixtime(windowstart)) as first_attempt,
    MAX(from_unixtime(windowend)) as last_attempt
FROM vpc_flow_logs 
WHERE 
    action = 'REJECT'
    AND year = cast(year(current_date) as varchar)
    AND month = cast(month(current_date) as varchar)
    AND day = cast(day(current_date) as varchar)
    AND hour >= cast((hour(current_timestamp) - 1) as varchar)
GROUP BY srcaddr
HAVING COUNT(DISTINCT dstport) > 50
ORDER BY unique_ports DESC
LIMIT 10;
EOF
}

resource "aws_athena_named_query" "ddos_detection" {
  name        = "ddos_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect DDoS attacks based on packet volume"

  query = <<EOF
SELECT 
    dstaddr,
    SUM(packets) as total_packets,
    SUM(bytes) as total_bytes,
    COUNT(DISTINCT srcaddr) as unique_sources,
    MIN(from_unixtime(windowstart)) as attack_start,
    MAX(from_unixtime(windowend)) as attack_end
FROM vpc_flow_logs
WHERE 
    action = 'ACCEPT'
    AND year = cast(year(current_date) as varchar)
    AND month = cast(month(current_date) as varchar)
    AND day = cast(day(current_date) as varchar)
    AND hour >= cast((hour(current_timestamp) - 1) as varchar)
GROUP BY dstaddr
HAVING 
    SUM(packets) > 100000
    OR COUNT(DISTINCT srcaddr) > 100
ORDER BY total_packets DESC
LIMIT 10;
EOF
}

resource "aws_athena_named_query" "data_exfiltration_detection" {
  name        = "data_exfiltration_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect potential data exfiltration"

  query = <<EOF
SELECT 
    srcaddr,
    dstaddr,
    SUM(bytes) as total_bytes,
    COUNT(*) as connection_count,
    AVG(bytes) as avg_bytes_per_connection,
    MIN(from_unixtime(windowstart)) as first_connection,
    MAX(from_unixtime(windowend)) as last_connection
FROM vpc_flow_logs 
WHERE 
    action = 'ACCEPT'
    AND dstport IN (80, 443, 21, 22)
    AND year = cast(year(current_date) as varchar)
    AND month = cast(month(current_date) as varchar)
    AND day = cast(day(current_date) as varchar)
    AND hour >= cast((hour(current_timestamp) - 1) as varchar)
GROUP BY srcaddr, dstaddr
HAVING SUM(bytes) > 100000000  -- 100MB threshold
ORDER BY total_bytes DESC
LIMIT 10;
EOF
}

resource "aws_athena_named_query" "unusual_protocol_detection" {
  name        = "unusual_protocol_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect unusual protocol usage"

  query = <<EOF
SELECT 
    protocol,
    COUNT(*) as connection_count,
    COUNT(DISTINCT srcaddr) as unique_sources,
    COUNT(DISTINCT dstaddr) as unique_destinations,
    SUM(bytes) as total_bytes
FROM vpc_flow_logs
WHERE 
    protocol NOT IN (6, 17, 1)  -- Not TCP, UDP, or ICMP
    AND action = 'ACCEPT'
    AND year = cast(year(current_date) as varchar)
    AND month = cast(month(current_date) as varchar)
    AND day = cast(day(current_date) as varchar)
    AND hour >= cast((hour(current_timestamp) - 1) as varchar)
GROUP BY protocol
ORDER BY connection_count DESC;
EOF
}

# Data sources para referencias
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}