# The public S3 buckets the Fastly services in this directory front. Only what
# is already public through the CDN is codified here; ACLs and public access
# block settings are intentionally left unmanaged.

# Origin of the cache service (cache.ruby-lang.org / ftp.ruby-lang.org). This
# bucket lives in us-east-1, unlike everything else in this account.
resource "aws_s3_bucket" "ftp" {
  bucket = "ftp.r-l.o"
  region = "us-east-1"

  tags = {
    Name = "ftp.r-l.o"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "ftp" {
  bucket = aws_s3_bucket.ftp.bucket
  region = "us-east-1"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Allow Public Access to All Objects"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:GetObjectTagging"]
        Resource  = ["arn:aws:s3:::ftp.r-l.o", "arn:aws:s3:::ftp.r-l.o/*"]
      },
    ]
  })
}

resource "aws_s3_bucket_versioning" "ftp" {
  bucket = aws_s3_bucket.ftp.bucket
  region = "us-east-1"

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ftp" {
  bucket = aws_s3_bucket.ftp.bucket
  region = "us-east-1"

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ftp" {
  bucket = aws_s3_bucket.ftp.bucket
  region = "us-east-1"

  # What the buckets already carry. Omitting this would flip them to the
  # provider default of all_storage_classes_128K.
  transition_default_minimum_object_size = "varies_by_storage_class"

  rule {
    id     = "lifecycle"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "INTELLIGENT_TIERING"
    }

    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Origin of the logs.rubyci.org service (chkbuild logs).
resource "aws_s3_bucket" "rubyci" {
  bucket = "rubyci"

  tags = {
    Name = "rubyci"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "rubyci" {
  bucket = aws_s3_bucket.rubyci.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Allow Public Access to All Objects"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource  = ["arn:aws:s3:::rubyci", "arn:aws:s3:::rubyci/*"]
      },
    ]
  })
}

# Suspended is deliberate here, unlike ftp.r-l.o; do not align the two.
resource "aws_s3_bucket_versioning" "rubyci" {
  bucket = aws_s3_bucket.rubyci.bucket

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rubyci" {
  bucket = aws_s3_bucket.rubyci.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "rubyci" {
  bucket = aws_s3_bucket.rubyci.bucket

  transition_default_minimum_object_size = "varies_by_storage_class"

  rule {
    id     = "lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    expiration {
      expired_object_delete_marker = true
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_website_configuration" "rubyci" {
  bucket = aws_s3_bucket.rubyci.bucket

  index_document {
    suffix = "index.html"
  }
}

# Backend of the archive.ruby-lang.org service. Versioning has never been
# enabled on this bucket, so there is no aws_s3_bucket_versioning resource
# for it.
resource "aws_s3_bucket" "blade" {
  bucket = "blade.ruby-lang.org"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "blade" {
  bucket = aws_s3_bucket.blade.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Allow Public Access to All Objects"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:GetObjectTagging"]
        Resource  = ["arn:aws:s3:::blade.ruby-lang.org", "arn:aws:s3:::blade.ruby-lang.org/*"]
      },
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "blade" {
  bucket = aws_s3_bucket.blade.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# A redirect to the bucket's own S3 hostname over plain http. Nothing serves
# through the website endpoint (archive.tf points Fastly at the REST endpoint),
# so this is likely a leftover, transcribed as found.
resource "aws_s3_bucket_website_configuration" "blade" {
  bucket = aws_s3_bucket.blade.bucket

  redirect_all_requests_to {
    host_name = "blade.ruby-lang.org.s3-ap-northeast-1.amazonaws.com"
    protocol  = "http"
  }
}

import {
  to = aws_s3_bucket.ftp
  id = "ftp.r-l.o@us-east-1"
}

import {
  to = aws_s3_bucket_policy.ftp
  id = "ftp.r-l.o@us-east-1"
}

import {
  to = aws_s3_bucket_versioning.ftp
  id = "ftp.r-l.o@us-east-1"
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.ftp
  id = "ftp.r-l.o@us-east-1"
}

import {
  to = aws_s3_bucket_lifecycle_configuration.ftp
  id = "ftp.r-l.o@us-east-1"
}

import {
  to = aws_s3_bucket.rubyci
  id = "rubyci"
}

import {
  to = aws_s3_bucket_policy.rubyci
  id = "rubyci"
}

import {
  to = aws_s3_bucket_versioning.rubyci
  id = "rubyci"
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.rubyci
  id = "rubyci"
}

import {
  to = aws_s3_bucket_lifecycle_configuration.rubyci
  id = "rubyci"
}

import {
  to = aws_s3_bucket_website_configuration.rubyci
  id = "rubyci"
}

import {
  to = aws_s3_bucket.blade
  id = "blade.ruby-lang.org"
}

import {
  to = aws_s3_bucket_policy.blade
  id = "blade.ruby-lang.org"
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.blade
  id = "blade.ruby-lang.org"
}

import {
  to = aws_s3_bucket_website_configuration.blade
  id = "blade.ruby-lang.org"
}
