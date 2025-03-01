# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = var.tf_state_project_id
  region  = var.google_default_region
}

data "google_project" "project" {}

resource "google_storage_bucket" "tf_state_bucket" {
  name                        = "tf-state-bucket-${var.tf_state_project_id}"
  location                    = var.google_default_region
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

#resource "local_file" "tf_backend_config" {
#  file_permission = "0644"
#  filename        = "backend.tf"
#  content = templatefile("../templates/backend.tf.tpl", {
#    bucket = google_storage_bucket.tf_state_bucket.name
#    prefix = "state"
#  })
#}

module "data_store" {
  source = "./modules/data-store"

  source_ga4_export_project_id = var.source_ga4_export_project_id
  source_ga4_export_dataset    = var.source_ga4_export_dataset
  source_ads_export_data       = var.source_ads_export_data

  data_processing_project_id = var.data_processing_project_id
  data_project_id            = var.data_project_id

  dataform_github_repo  = var.dataform_github_repo
  dataform_github_token = var.dataform_github_token

  create_dev_environment     = var.create_dev_environment
  create_staging_environment = var.create_staging_environment
  create_prod_environment    = var.create_prod_environment

  staging_data_project_id = var.staging_data_project_id

  project_owner_email = var.project_owner_email
}

locals {
  source_root_dir  = "../.."
  config_file_name = "config"
  poetry_run_alias = "${var.poetry_cmd} run"
}

resource "local_file" "feature_store_configuration" {
  filename = "${local.source_root_dir}/config/${local.config_file_name}.yaml"
  content = templatefile("${local.source_root_dir}/config/${var.feature_store_config_env}.yaml.tftpl", {
    project_id             = data.google_project.project.project_id
    project_name           = data.google_project.project.name
    project_number         = data.google_project.project.number
    mds_dataset            = "${var.mds_dataset_prefix}_${var.feature_store_config_env}"
    pipelines_github_owner = var.pipelines_github_owner
    pipelines_github_repo  = var.pipelines_github_repo
  })
}

resource "null_resource" "poetry_install" {
  provisioner "local-exec" {
    command     = "${var.poetry_cmd} install"
    working_dir = local.source_root_dir
  }
}


resource "null_resource" "generate_sql_queries" {

  triggers = {
    working_dir = local.source_root_dir
  }

  provisioner "local-exec" {
    command     = <<-EOT
    ${local.poetry_run_alias} inv apply-env-variables-datasets --env-name=${local.config_file_name}
    ${local.poetry_run_alias} inv apply-env-variables-tables --env-name=${local.config_file_name}
    ${local.poetry_run_alias} inv apply-env-variables-queries --env-name=${local.config_file_name}
    ${local.poetry_run_alias} inv apply-env-variables-procedures --env-name=${local.config_file_name}
    EOT
    working_dir = self.triggers.working_dir
  }

  provisioner "local-exec" {
    when        = destroy
    command     = <<-EOT
    rm sql/schema/dataset/*.sql
    rm sql/table/*.sql
    rm sql/query/*.sql
    rm sql/procedure/*.sql
    EOT
    working_dir = self.triggers.working_dir
  }

  depends_on = [
    local_file.feature_store_configuration,
    null_resource.poetry_install
  ]
}

module "feature_store" {
  source           = "./modules/feature-store"
  config_file_path = local_file.feature_store_configuration.filename
  enabled          = var.deploy_feature_store
  count            = var.deploy_feature_store ? 1 : 0

  depends_on = [
    null_resource.generate_sql_queries
  ]
}

module "pipelines" {
  source           = "./modules/pipelines"
  config_file_path = local_file.feature_store_configuration.filename
  poetry_run_alias = local.poetry_run_alias
  count            = var.deploy_pipelines ? 1 : 0
  depends_on = [
    null_resource.poetry_install
  ]
}

module "activation" {
  source                 = "./modules/activation"
  project_id             = var.activation_project_id
  location               = var.google_default_region
  ga4_measurement_id     = var.ga4_measurement_id
  ga4_measurement_secret = var.ga4_measurement_secret
  count                  = var.deploy_activation ? 1 : 0
}