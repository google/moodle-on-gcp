# Project overview

**Moodle** is one of the most popular Learning Management Systems (LMS) platforms in the world with +175 thousand instalations globally serving milions of students and teachers every day.

**Modern Moodle in Google Cloud Platform** project is all about taking Moodle (which is 20-years-old now) insfrastructure and hosting model and modernizing it to add maximum performance, resiliense and make available to institutions all the flexibility that a public cloud platform can provide. 

We do this on top of [Google Cloud](https://cloud.google.com/) platform services.

## Benefits

Customers can greatly benefit themselves by leveraging a cloud native approach like **Modern Moodle on GCP** with the main ones being:

* **Quick go-to-market**. All the complexity related to get all those pieces together and working properly were taken away from you, as we have already scripted everything and made it available in this GitHub repository. It means that institutions can simply follow the steps described in the repository's documentation to get it deployed quickly.
Cloud native. This implementation of Moodle is 100% cloud native, which means that all the services utilized by the solution are built-in in GCP (no more Virtual Machines management whatsoever) and automatically leverages all the benefits enabled by default by Google Cloud, like automation, self-healing, scalability and cost-effectiveness.

* **Highly-scalable**. The solution makes Moodle stateless, which means it can now scale up and down with no damage to users' in-memory data. Also, with GKE we can scale horizontally Moodle's pods and cluster's nodes, allowing web application to be always on. Underlying services are also highly scalable, which means that all the pieces can follow GKE's auto scalability.
  
* **Open-source**. The implementation of the solution is publicly available in GitHub, which means that institutions can both collaborate with our engineers (helping us make this offer even better for everyone), and take it as a starting point for building something tailor-made to themselves.

* **Continuous Integration (CI) and Continuous Deployment (CD) ready**. The solution was designed to work smoothly with new or existing DevOps automation practices. For that, Google recommends leveraging GCP's Artifact Registry and Cloud Build services.
Multi-sized environment options. We're starting the project with an enterprise version for Moodle (using GKE as base for running Moodle's instances), which is more suitable for bigger environments (+5000 users), however, soon we will bring Moodle to a serverless model, which will allow smaller environments and institutions to get it running under a low-cost. 

* **Cost-effective**. We customized every step of the deployment to make sure all the resources are optimal with the initial setup. The cost is also optimal for the initial deployment.

* **Security embedded**. On top of Cloud Armor (for WAF) and reCAPTCHA (for access validation), we deploy the entire solution in private mode. It means that all the services supporting it cannot be publicly accessed. Only internal resources (from the same Virtual Private Network) can access the services  (for maintenance purposes, for instance).

## How it works?

From a high-level perspective, what we did was bringing together a set of shell scripts and Kubernetes (YAML) config files that, when executed in order, build the entire infrastructure needed to support Moodle in Google Cloud and then, deploys Moodle itself with all the configuration needed already in place.

Please, visit [Deployment](docs/deployment.md) section in README to see details about how to get it deployed in your environment.

## Cost view

If the architecture gets deployed the way it originally sits on the repo, it will going to cost something around **US$ 2,300.00/month**, as you can see through [this simulation](https://cloud.google.com/products/calculator/#id=35a411a3-30b8-4409-b3d8-f88a28b6e97e) in Google Cloud calculator.

However, it is important to acknowledge that customizations on that  deployment of services (in file [infra-creation.sh](~/../../0-infra/infra-creation.sh)) can impact directly that amount. So please, be aware of it when customizing the script.

Also, eventual commercial agreements previously set with Google (or with one of its partners) can deviate that amount from the simulation price here described, as discounts are usually applied to GCP's SKUs. In case of doubts on that regard, please, reach out your GCP field sales representative.