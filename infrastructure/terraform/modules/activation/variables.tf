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

variable "project_id" {
  type        = string
  description = "Google Cloud Project ID"
}

variable "location" {
  description = "Pipeline location."
  type        = string
  default     = "us-central1"
}

variable "artifact_repository_id" {
  description = "Container repository id"
  type        = string
  default     = "activation-docker-repo"
}

variable "trigger_function_location" {
  description = "Location of the trigger cloud function"
  type        = string
  default     = "us-central1"
}

variable "ga4_measurement_id" {
  description = "Measurement ID in GA4"
  type        = string
}

variable "ga4_measurement_secret" {
  description = "client secret for authenticatin to GA4 api"
  type        = string
}