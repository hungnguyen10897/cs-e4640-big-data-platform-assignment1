# Assignment 1 Report


* your designs
* your test results


## Answers to Questions in the Assignment
<br>

### Part 1 - Design

<br>

**1. Explain your choice of types of data to be supported and technologies for *mysimbdp-coredms* (1 point)**

<br>

Data used for this assignment is [Amazon US Customer Reviews Dataset](https://www.kaggle.com/cynthiarempel/amazon-us-customer-reviews-dataset). For this data,
I decided to use [Apache Cassandra](https://cassandra.apache.org/) for **mysimbdp-coredms**. Here are the reasoning:

 - The volume of this type of data (`reviews`) is huge. Therefore, a NoSQL database is ideal since it supports horizontal scaling by adding nodes to the cluster
 in addition to the expensive vertical scaling.

 - Only READ and WRITE operations need to be supported. There won't be any UPDATE in reviews data. Customers seldom change their reviews. Even in case of changes, updated
 reviews can be regarded as new reviews. This does not affect the integrity of the data.

 - The data is not mission-critical and does not require ACID. Reviews data are not important for operational usage, thus, would not require a transactional RDBMS. Furthermore,
 immediate consistency is not essential as in transactional data, eventual consistency would be just fine. Missing a small number of reviews wouldn't be an issue.

 - The data is still structured. Although opting for NoSQL, the data itself is still structured with 15 defined columns and their respective types. Cassandra is still ideal for 
 structured data.

 - Some columns contain overly long texts. This is not optimized for row-based storage of traditional RDBMS, but ideal for Cassandra.

 - Clear use case of the data. Reviews are most probably group by each product. Therefore, we already have a clear way to partition and layout the data, by `product_id`. 
 Queries will be only supported to filter with `product_id` (`WHERE product_id = "<SOME_PRODUCT>"`). This is important when using Cassandra.

 - Only 1 table in the dataset, therefore, there is no need for `JOIN` operation which is not supported by Cassandra

<br>
<br>

**2. Design and explain interactions between main components in your architecture of *mysimbdp* (1 point)**

<br>

Cassandra is deployed onto a Kubernetes Cluster and manged by K8ssandra, which will be the **mysimbdp-coredms** component. K8ssandra comes with Stargate, which
exposes several endpoints at different ports for connecting and interacting with Cassandra. **mysimbdp-dataingest** is composed of several python processes writing
to Cassandra through Stargate. For simplicity, Stargate service are port-forwarded to localhost so that the python processes of **mysimbdp-dataingest**, which are 
deployed by `docker-compose` can access via host network.

In addition, there are Grafana and Prometheus services that can be accessed to monitor K8ssandra. These are also port-forwarded to the host network for easy access.

<br>
<br>

**3. Explain a configuration of a cluster of nodes for *mysimbdp-coredms* so that you prevent a single-point-of-failure problem for *mysimbdp-coredms* for your tenants (1 point)**

<br>

Kubernetes is running on a cluster of at least 3 workers (simulated with [minikube](https://minikube.sigs.k8s.io/docs/)). Therefore, each worker will have at least 1 instance of Cassandra running on a pod. This helps prevent
a single point of failure if any 1 worker/node fails in the cluster.

<br>
<br>

**4. You decide a pre-defined level of data replication for your tenants/customers. Explain how many nodes are needed in the deployment of
*mysimbdp-coredms* for your choice so that this component can work property (e.g., the system still supports redundancy in the case of a failure of a node) (1 point)**

<br>

Similar to Part 1 Point 3 above, the Cluster needs to consist of at least 3 nodes. Furthermore, the `replciation_factor` of any `KEYSPACE` needs to be at least 3 and 
smaller than the number of nodes.

<br>
<br>

**5. Explain how would you scale *mysimbdp* to allow many tenants using *mysimbdp-dataingest* to push data into *mysimbdp* (1 point)**

<br>

Scaling would be extremely straightforward when using K8ssandra on Kubernetes. This can be done either vertically or horizontally:

- Vertical Scaling: Increase `resources.requests` and `resouces.limits` under [k8ssandra values](../code/mysimdbp-coredms/k8ssandra.yaml)
- Horizontal Scaling: Add nodes/workers to the Kubernetes Cluster and then increase `datacenters.size` under [k8ssandra values](../code/mysimdbp-coredms/k8ssandra.yaml)

<br>
<br>

### Part 2 - Implementation

<br>

**1. Design, implement and explain one example of the data schema/structure for a tenant whose data will be stored into *mysimbdp-coredms* (1 point)**

<br>

Tenant can create their own `KEYSPACE` (database), `Column Family` (Table) with defined schema into Cassandra. All of this can be defined in a `.cql` file and 
execute via `cqlsh`. A sample can be found under [setup.cql](../code/mysimdbp-coredms/setup.cql)

<br>
<br>

**2. Given the data schema/structure of the tenant (Part 2, Point 1), design a strategy for data partitioning/sharding and explain your implementation 
for data partitioning/sharding together with your design for replication in Part 1, Point 4, in *mysimbdpcoredms* (1 point)**

<br>

For Cassandra, when creating table, we already need to take into account the type of queries we are going to execute. Then, decide on the `PRIMARY KEY` which composes 
of `PARTITION_KEY` (which node the data goes to) and `CLUSTERING_COLUMNS` (how data is laid out in the node - optional). For this kind of `reviews` data, query will be 
only filtered by 1 specific product (`product_id`). Thus, I choose `product_id` to be the `PARTITION_KEY`. Together with `replication = {'class': 'SimpleStrategy', 'replication_factor': 3}`,
data, after partitioned to a node, will be replicated to the next 2 nodes in the cluster in clock-wise order.

All of these are defined in [setup.cql](../code/mysimdbp-coredms/setup.cql) file.

<br>
<br>

**3. Assume that you are the tenant, write a *mysimbdp-dataingest* that takes data from your selected sources and stores the data into *mysimbdp-coredms*. 
Explain possible consistency options for writing data in your mysimdbp-dataingest (1 point)**

<br> 

A sample script for *mysimbdp-dataingest* can be found [here](../code/mysimbdp-dataingest/producer.py). The script reads some sample data stored at `/code/mysimbdp-dataingest/data/` 
and write to the default Keyspace on Cassandra. 

The Cassandra consistency level is defined as the minimum number of Cassandra nodes that must acknowledge a read or write operation before the operation can be considered successful. 

Consistency level can have value LOCAL_QUORUM for a data center:

```
LOCAL_QUORUM = (replication_factor/2) + 1 
```

For example, if `replication_factor` is equal to 3, (3/2) +1 = 2 (the value is rounded down to an integer). With LOCAL_QUORUM = 2, at least two of the three Cassandra nodes in the data center
must respond to a read/write operation for the operation to succeed. For a three node Cassandra cluster, the cluster could therefore tolerate one node being down per data center.

<br>
<br>

**4. Given your deployment environment, show the performance (response time and failure) of the tests for 1,5, 10, .., n of concurrent *mysimbdp-dataingest* 
writing data into *mysimbdp-coredms* with different speeds/velocities together with the change of the number of nodes of *mysimbdp-coredms*. Indicate any performance 
differences due to the choice of consistency options (1 point)**

Write Request throughput:


![Request Throughput](./images/rt.png)


Write Latency:

![Write Latency](./images/latency.png)


<br>

Although the through put increase by 2-2.5 times, latency only increases by about 1.5 times. Due to limitations of, computing resources and time, 
I didn't have time to test scaling of K8ssandra to handle the workload.


<br>
<br>

**5. Observing the performance and failure problems when you push a lot of data into *mysimbdp-coredms* 
(you do not need to worry about duplicated data in *mysimbdp*), propose the change of your deployment to avoid 
such problems (or explain why you do not have any problem with your deployment) (1 point)**

Performance can be improved by scaling K8ssandra on Kubernetes cluster (Part 1 - Point 5).


<br>
<br>

### Part 3 Extension

<br>

**1. Using your *mysimdbp-coredms*, a single tenant can create many different databases/datasets. Assume that you want to
support the tenant to manage metadata about the databases/datasets, what would be your solution? (1 point)**

<br>

We can have a metadata table stored directly in the Keyspace with the following schema:

```
USE mysimbdp;

CREATE TABLE metadata (
  table_name TEXT,
  organization TEXT,
  table_schema MAP<TEXT,TEXT>,
  description TEXT,
  creator_id UUID,
  created_at TIMESTAMP,
  last_updated_at TIMESTAMP,
  PRIMARY KEY (table_name)
);
```

Users can easily extract data about related tables within the scope of a tenant/organization.

<br>
<br>

**2. Assume that each of your tenants/users will need a dedicated *mysimbdp-coredms*. Design the data schema of service
information for *mysimbdp-coredms* that can be published into an existing registry (like ZooKeeper, consul or etcd) so that
you can find information about which *mysimbdp-coredms* is for which tenants/users (1 point)**

<br>

Data Schema of Service Information:

```
host_address TEXT         # IP Address where the *mysimbdp-coredms* for the tenant can be reached
keyspace_name TEXT        # Name of Keyspace, different tenants can share the same *mysimbdp-coredms*
tenant_id UUID            # Tenant ID owning the combination of host_address and keyspace_name
tenant_name TEXT          # Alternative name of the tenant
tenant_description TEXT   # General description
```

<br>
<br>

**3. Explain how you would change the implementation of *mysimbdp-dataingest* (in Part 2) to integrate a service discovery
feature (no implementation is required) (1 point)**

<br>

**mysimbdp-dataingest**, instead of going directly to the host address of the Cassandra cluster hosting `mysimbdp` coredms service 
and authenticate against it, will query available services using the service discovery feature to extract information about the wanted
service first, like its addrsess, keyspace name. Only after that, it reaches the end service.

<br>
<br>

**4. Assume that now only *mysimbdp-daas* can read and write data into *mysimbdp-coredms*, how would you change your
*mysimbdp-dataingest* (in Part 2) to work with *mysimbdp-daas*? (1 point)**

<br>

**mysimbdp-dataingest** will point to **mysimbdp-daas** APIs and authenticates against it instead of authenticating directly to
**mysimbdp-coredms**. There would be fine-grained access control at **mysimbdp-daas**, it can define only a set of READ/WRITE operations
that clients can perform, exposing those as REST APIs taking parameters to prepare and run CQL Query. **mysimbdp-dataingest** has to 
call REST APIs of **mysimbdp-daas** rather than performing whatever it wants at **mysimbdp-coredms**.

<br>
<br>

**5. Assume that you design APIs for *mysimbdp-daas* so that any other developer who wants to implement *mysimbdpdataingest* can 
write his/her own ingestion program to write the data into *mysimbdp-coredms* by calling *mysimbdp-daas*.
Explain how would you control the data volume and speed in writing and reading operations for a tenant? (1 point)**

<br>

**mysimbdp-daas** can enforce compulsory `parameters` regarding READ/WRITE volume and speed or having a reasonable default 
value. For volume, clients can only READ/WRITE, for instance, 1GB of data per request. At the same time for speed, clients can only send
10 requests per minute.

<br>
<br>
