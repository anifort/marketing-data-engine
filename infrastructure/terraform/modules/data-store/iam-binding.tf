# Copyright 2022 Google LLC
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

# TODO: we might not need to have this email role at all.
resource "google_project_iam_member" "email-role" {
  for_each = toset([
    "roles/iam.serviceAccountUser", // TODO: is it really needed?
    "roles/dataform.admin",
    "roles/dataform.editor"
  ])
  role    = each.key
  member  = "user:${var.project_owner_email}"
  project = data.google_project.data_processing.project_id
}

resource "google_project_iam_member" "dataform-serviceaccount" {
  depends_on = [google_dataform_repository.marketing-analytics]
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/bigquery.jobUser"
  ])
  role    = each.key
  member  = "serviceAccount:service-${data.google_project.data_processing.number}@gcp-sa-dataform.iam.gserviceaccount.com"
  project = data.google_project.data_processing.project_id
}

locals {
  dataform_sa = "service-${data.google_project.data_processing.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}
// Owner role to BigQuery in the destination data project the Dataform SA.
// Multiple datasets will be created; it requires project-level permissions
resource "google_project_iam_member" "dataform-bigquery-data-owner" {
  depends_on = [google_dataform_repository.marketing-analytics]
  for_each = toset([
    "roles/bigquery.dataOwner",
  ])
  role    = each.key
  member  = "serviceAccount:${local.dataform_sa}"
  project = data.google_project.data.project_id
}

// Read access to the GA4 exports
resource "google_bigquery_dataset_iam_member" "dataform-ga4-export-reader" {
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${local.dataform_sa}"
  project    = var.source_ga4_export_project_id
  dataset_id = var.source_ga4_export_dataset
}

// Read access to the Ads datasets
resource "google_bigquery_dataset_iam_member" "dataform-ads-export-reader" {
  count      = length(var.source_ads_export_data)
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${local.dataform_sa}"
  project    = var.source_ads_export_data[count.index].project
  dataset_id = var.source_ads_export_data[count.index].dataset
}
