# cloud-cml-img
Build Cisco Modeling Labs (CML) Controller and Compute Images for Becoming a
Hacker Lab on Google Cloud Platform.

## How to upgrade

* Copy new CML packages to gs://bah-machine-images/cml2.  These can be found
  internally on Cisco's network at https://virlbuilds.cisco.com/fcs/
* Edit `cloudbuild.yml` file to choose a base Ubuntu image and Debian Package
  for CML.
* Commit and push.  [Cloud Build](https://console.cloud.google.com/cloud-build/dashboard;region=us-east1?inv=1&invt=AbnoiA&project=gcp-asigbahgcp-nprd-47930) takes care of the rest.
