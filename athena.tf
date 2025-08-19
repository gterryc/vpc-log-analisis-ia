# Glue Database
resource "aws_glue_catalog_database" "vpc_flow_logs" {
  name        = "${local.project_name}_flow_logs_db"
  description = "Database for VPC Flow Logs analysis"
  tags        = local.common_tags

}

# Workgroup de Athena
resource "aws_athena_workgroup" "anomaly_detection" {
  name          = "${local.project_name}-workgroup"
  description   = "Workgroup para Demo de AWS Community Fest"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://${var.bucket_name}-athena-results/" 
    }

    bytes_scanned_cutoff_per_query = 1073741824 # 1GB limit
  }

  tags = local.common_tags
}

resource "aws_glue_catalog_table" "vpc_flow_logs" {
  name          = "vpc_flow_logs"
  database_name = aws_glue_catalog_database.vpc_flow_logs.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification = "csv"
    "typeOfData"   = "file"

    # Partition Projection habilitada
    "projection.enabled"      = "true"

    # Year
    "projection.year.type"    = "integer"
    "projection.year.range"   = "2020,2035"

    # Month
    "projection.month.type"   = "integer"
    "projection.month.range"  = "1,12"
    "projection.month.digits" = "2"

    # Day
    "projection.day.type"     = "integer"
    "projection.day.range"    = "1,31"
    "projection.day.digits"   = "2"

    # Debe coincidir con tu layout real (no Hive key=value)
    "storage.location.template" = "s3://anomaly-detection-flow-logs-12051980/AWSLogs/730335323500/vpcflowlogs/us-east-1/$${year}/$${month}/$${day}/"
  }

  storage_descriptor {
    location      = "s3://anomaly-detection-flow-logs-12051980/AWSLogs/"
    #location      = "s3://${var.bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${data.aws_region.current.id}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim"          = " "
        "serialization.format" = " "
      }
    }

    # Columnas (mismo orden que tu DDL)
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
      type = "bigint"
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
      name = "start"        
      type = "bigint"
    }

    columns { 
      name = "end"          
      type = "bigint" 
    }

    columns { 
      name = "action"       
      type = "string"
    }

    columns { 
      name = "log_status"   
      type = "string"
    }
  }

  # Particiones por día (para projection)
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
}

# ===========================================
# Named Queries para detección de anomalías
# ===========================================

# Propósito principal: 
# Identifica direcciones IP que están intentando conectarse a muchos puertos diferentes y siendo rechazadas, 
# lo cual es un patrón típico de escaneo de puertos.

resource "aws_athena_named_query" "port_scanning_detection" {
  name        = "port_scanning_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect port scanning activities"

  query = <<EOF
SELECT 
  srcaddr,
  COUNT(DISTINCT dstport) AS unique_ports,
  COUNT(*) AS total_attempts,
  MIN(to_iso8601(from_unixtime(start))) AS first_attempt,
  MAX(to_iso8601(from_unixtime("end"))) AS last_attempt
FROM vpc_flow_logs
WHERE 
  log_status = 'OK'
  AND action = 'REJECT'
  AND year = CAST(year(current_date) AS varchar)
  AND month = LPAD(CAST(month(current_date) AS varchar), 2, '0')
  AND day = LPAD(CAST(day(current_date) AS varchar), 2, '0')
GROUP BY srcaddr
HAVING COUNT(DISTINCT dstport) > 50
ORDER BY unique_ports DESC
LIMIT 10;
EOF
}

# Propósito principal: 
# Identifica direcciones IP de destino que están recibiendo un volumen inusualmente alto de tráfico o conexiones desde 
# múltiples fuentes, indicando posibles ataques DDoS o tráfico anómalo.

resource "aws_athena_named_query" "ddos_detection" {
  name        = "ddos_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect DDoS attacks based on packet volume"

  query = <<EOF
SELECT 
  dstaddr,
  SUM(packets) AS total_packets,
  SUM(bytes) AS total_bytes,
  COUNT(DISTINCT srcaddr) AS unique_sources,
  MIN(to_iso8601(from_unixtime(start))) AS attack_start,
  MAX(to_iso8601(from_unixtime("end"))) AS attack_end
FROM vpc_flow_logs
WHERE
  log_status = 'OK'
  AND action IN ('ACCEPT','REJECT')
  AND year = CAST(year(current_date) AS varchar)
  AND month = LPAD(CAST(month(current_date) AS varchar), 2, '0')
  AND day = LPAD(CAST(day(current_date) AS varchar), 2, '0')
GROUP BY dstaddr
HAVING 
  SUM(packets) > 100000
  OR COUNT(DISTINCT srcaddr) > 100
ORDER BY total_packets DESC
LIMIT 10;
EOF
}

# Propósito principal: 
# Identifica conexiones específicas (par origen-destino) que han transferido grandes volúmenes de datos a través de puertos 
# de servicios comunes, lo cual podría indicar exfiltración de datos o transferencias anómalas.

resource "aws_athena_named_query" "data_exfiltration_detection" {
  name        = "data_exfiltration_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect potential data exfiltration"

  query = <<EOF
SELECT 
  srcaddr,
  dstaddr,
  SUM(bytes) AS total_bytes,
  COUNT(*) AS connection_count,
  AVG(bytes) AS avg_bytes_per_connection,
  MIN(to_iso8601(from_unixtime(start))) AS first_connection,
  MAX(to_iso8601(from_unixtime("end"))) AS last_connection
FROM vpc_flow_logs
WHERE 
  log_status = 'OK'
  AND action = 'ACCEPT'
  AND dstport IN (80, 443, 21, 22)
  AND year = CAST(year(current_date) AS varchar)
  AND month = LPAD(CAST(month(current_date) AS varchar), 2, '0')
  AND day = LPAD(CAST(day(current_date) AS varchar), 2, '0')
GROUP BY srcaddr, dstaddr
HAVING SUM(bytes) > 25000000    -- 25 MB
ORDER BY total_bytes DESC
LIMIT 10;
EOF
}

# Propósito principal: 
# Identifica tráfico de red que usa protocolos diferentes a los estándar (TCP, UDP, ICMP), 
# lo cual puede indicar actividad maliciosa, túneles encubiertos o herramientas de evasión.

resource "aws_athena_named_query" "unusual_protocol_detection" {
  name        = "unusual_protocol_detection"
  workgroup   = aws_athena_workgroup.anomaly_detection.name
  database    = aws_glue_catalog_database.vpc_flow_logs.name
  description = "Detect unusual protocol usage"

  query = <<EOF
SELECT 
  protocol,
  COUNT(*) AS connection_count,
  COUNT(DISTINCT srcaddr) AS unique_sources,
  COUNT(DISTINCT dstaddr) AS unique_destinations,
  SUM(bytes) AS total_bytes
FROM vpc_flow_logs
WHERE 
  log_status = 'OK'
  AND protocol NOT IN (6, 17, 1)  -- Not TCP, UDP, or ICMP
  AND action = 'ACCEPT'
  AND year = CAST(year(current_date) AS varchar)
  AND month = LPAD(CAST(month(current_date) AS varchar), 2, '0')
  AND day = LPAD(CAST(day(current_date) AS varchar), 2, '0')
GROUP BY protocol
ORDER BY connection_count DESC;
EOF
}
