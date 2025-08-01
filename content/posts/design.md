---
title: Oreo
draft: true
---

## Name

Oreo

## Database

Assumptions on the platforms:

- The option when reading for single-item strong consistency
- Atomic conditional update and delete on single items, similar to Test-and-Set.
- Ability to include user-defined meta-data along with the content of a data item.

### Redis

#### Conditional Set

Yes, we can use `lua-script` to do this:

```lua
local lts = tonumber(redis.call('GET', KEYS[1]))
local nts = tonumber(ARGV[1])
if lts < nts then
      redis.call('SET', KEYS[1], nts)
      redis.call('SET, KEYS[2], ARGV[2])
end
```

Or

```lua
EVAL "if redis.call('get', 'myKey') == 'expectedVal' then return redis.call('set', 'myKey', 'newVal') else return redis.error_reply('myKey has changed!') end" 0
```

Redis, unlike MongoDB, does not have a built-in query language or update operators for performing conditional updates directly like you would in a document store or relational database. Instead, updates in Redis are typically done by fetching the data, modifying it in the application, and then writing it back to Redis. For conditional updates, you would implement the condition checks in your application code.

However, if you want to perform atomic updates conditionally, you can use Lua scripting with Redis or the WATCH command for optimistic locking.

Here's a basic example of how you could perform a conditional set in Redis using Lua scripting with the go-redis library:

Firstly, install the go-redis package if you haven't:

```shell
go get github. Com/go-redis/redis/v8
```

Now here's an example of doing a conditional set in Redis:

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/go-redis/redis/v8"
)

func main() {
    // Create a new Redis client.
    rdb := redis.NewClient(&redis.Options{
        Addr:     "localhost:6379", // Your Redis address
        Password: "",               // No password set
        DB:       0,                // Use default DB
    })

    // Use context for timeout and cancellation.
    ctx := context.Background()

    // Define the Lua script for conditional set.
    // Key '1' will be checked if its value is "existing_value".
    // If condition matches, we will set the new value "new_value".
    script := `
        if redis.call("GET", KEYS[1]) == ARGV[1] then
            return redis.call("SET", KEYS[1], ARGV[2])
        else
            return 0
        end
    `

    // Using Eval to run the Lua script.
    // KEYS[1]: The key to be checked and possibly set.
    // ARGV[1]: The existing value we expect.
    // ARGV[2]: The new value to set if the condition matches.
    result, err := rdb.Eval(ctx, script, []string{"your_key"}, "existing_value", "new_value").Result()
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("Script result:", result)

    // Close the Redis client when finished.
    if err := rdb.Close(); err != nil {
        log.Fatal(err)
    }
}
```

#### Meta-data

Use `HSET`

```bash
redis> HSET myhash field2 "Hi" field3 "World"
(integer) 2
redis> HGET myhash field2
"Hi"
redis> HGET myhash field3
"World"
```

### MongoDB

#### Conditional Set

In Go (Golang), you use the MongoDB Go Driver to interact with MongoDB. To perform a conditional update, you build a filter to match the documents you want to update based on your conditions, and then use the update operators to change the data accordingly.

First, ensure you have the MongoDB Go Driver installed:

```shell
go get go.Mongodb.org/mongo-driver/mongo
go get go.Mongodb.org/mongo-driver/mongo/options
```

Here is an example of how to perform a conditional update using the MongoDB Go Driver in Golang:

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"

    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

func main() {
    // Set client options
    clientOptions := options.Client().ApplyURI("your-mongodb-uri") // Replace with your MongoDB URI

    // Connect to MongoDB
    client, err := mongo.Connect(context.TODO(), clientOptions)
    if err != nil {
        log.Fatal(err)
    }

    // Check the connection
    err = client.Ping(context.Background(), nil)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Connected to MongoDB!")

    // Get handle for your collection
    collection := client.Database("your-db-name").Collection("your-collection-name")

    // Define the filter for documents you want to update
    filter := bson.M{"reviewCount": bson.M{"$gt": 10}} // Documents with reviewCount > 10

    // Define the update operation
    update := bson.M{
        "$set": bson.M{
            "status": "approved",
        },
    }

    // Perform the update operation
    result, err := collection.UpdateMany(context.Background(), filter, update)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("Matched %v documents and updated %v documents.\n", result.MatchedCount, result.ModifiedCount}

    // Close the connection once no longer needed
    err = client.Disconnect(context.TODO())
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Connection to MongoDB closed.")
}
```

In the above example, replace your-mongodb-uri, your-db-name, and your-collection-name with your MongoDB connection string, database name, and collection name, respectively.

The key points in this program are: - Establishing a connection to the MongoDB server using mongo. Connect. - Creating a filter with the condition (bson. M{"reviewCount": bson. M{"$gt": 10}}) which matches documents where the field reviewCount is greater than 10. - Defining the update using the $set operator to change the status field to "approved" for documents that match the filter. - Calling collection. UpdateMany with the context, the filter, and the update definition to perform the update operation.

#### Meta-data

In a MongoDB database, we can store metadata as part of the documents in a collection. Since MongoDB is schema-less, you can structure your documents as you like, including any number of fields that could serve as metadata.

For example:

```json
{
    "_id": ObjectId("507f1f77bcf86cd799439011"),
    "filename": "picture.jpg",
    "fileSize": "500KB",
    "uploadDate": ISODate("2020-10-01T00:00:00Z"),
    "format": "jpg",
    "uploaderId": ObjectId("507f191e810c19729de860ea"),
    "tags": ["nature", "vacation"],
    "description": "A photo from my summer vacation."
}
```

### Couchdb

#### Conditional Update

To perform a conditional update in CouchDB using Golang, you would typically use the CouchDB REST API with a HTTP library in Golang, such as net/http or higher-level libraries like resty.

The general steps for performing a conditional update (also known as an update with conflict detection) in CouchDB from a Golang application are:

Retrieve the current document along with its \_rev (revision) field.
Modify the document in your application code.
Send an HTTP PUT request with the updated document and the \_rev field back to CouchDB.

If the \_rev field you’re sending back matches the current revision of the document in the database, CouchDB will allow the update. Otherwise, CouchDB will respond with a conflict error, indicating that the document has been updated by another process since you retrieved it.

Here's an example of how you might do this in Golang:

```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io/ioutil"
    "net/http"
)

type Document struct {
    ID    string `json:"_id"`
    Rev   string `json:"_rev,omitempty"`
    // Add other document-specific fields here
}

func getDocument(url string) (Document, error) {
    var doc Document
    resp, err := http.Get(url)
    if err != nil {
        return doc, err
    }
    defer resp.Body.Close()
    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return doc, err
    }
    err = json.Unmarshal(body, &doc)
    return doc, err
}

func updateDocument(url string, doc Document) error {
    docBytes, err := json.Marshal(doc)
    if err != nil {
        return err
    }
    req, err := http.NewRequest("PUT", url, bytes.NewBuffer(docBytes))
    if err != nil {
        return err
    }
    req.Header.Set("Content-Type", "application/json")

    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    // Check if update was successful, if not handle the conflict
    if resp.StatusCode != http.StatusCreated {
        // Handle response codes like 409 Conflict here
        body, _ := ioutil.ReadAll(resp.Body)
        fmt.Printf("CouchDB Error: %s\n", body)
        return fmt.Errorf("couchdb error: %s", resp.Status)
    }
    return nil
}

func main() {
    couchdbUrl := "http://localhost:5984/mydb/mydocid"

    // Retrieve the document you want to update
    doc, err := getDocument(couchdbUrl)
    if err != nil {
        // Handle error
        fmt.Println(err)
        return
    }

    // Modify the document as needed
    // doc.<field> = <new value>

    // Update the document with the new revision
    err = updateDocument(couchdbUrl, doc)
    if err != nil {
        // Handle error
        fmt.Println(err)
        return
    }
}
```

In this code sample:

The getDocument function retrieves a document from CouchDB and returns it along with its current \_rev id.
The updateDocument function takes an updated document and sends it back to CouchDB. It looks at the HTTP response to determine if the update was successful or if there was a conflict.
The main function is an example of how to retrieve a document, modify it, and try to update it in CouchDB.

Please note that you will need to modify the Document struct to include the actual fields present in your documents and handle additional error cases or HTTP response statuses as appropriate for your application's requirements.

#### Meta-data

CouchDB allows you to add user-defined (custom) metadata fields to any document. Generally, custom metadata fields are just like any other fields in a document, and you can include them as needed. However, you should avoid using field names that begin with an underscore (\_) because those are reserved for CouchDB's own metadata (like \_id, \_rev, etc.).

Here's an example of how you might add custom metadata to a CouchDB document using Golang:

Define the document structure, including any custom metadata fields:

```go
type CustomDocument struct {
    ID      string `json:"_id"`
    Rev     string `json:"_rev,omitempty"`
    Type    string `json:"type"`
    MyMeta  map[string]interface{} `json:"my_meta"`
    // Add other document-specific fields here
}
```

In this example, the MyMeta map can hold various key-value pairs that will serve as your custom metadata fields.

Insert the document with custom metadata using an HTTP POST request:

```go
func createDocumentWithMetadata(url string, doc CustomDocument) error {
    docBytes, err := json.Marshal(doc)
    if err != nil {
        return err
    }
    resp, err := http.Post(url, "application/json", bytes.NewBuffer(docBytes))
    if err != nil {
        return err
    }
    defer resp.Body.Close()
    if resp.StatusCode != http.StatusCreated {
        body, _ := ioutil.ReadAll(resp.Body)
        return fmt.Errorf("failed to create doc: %s, %s", resp.Status, body)
    }
    return nil
}

func main() {
    couchdbUrl := "http://localhost:5984/mydb"

    // Create and populate your document
    doc := CustomDocument{
        ID:     "mydocid",
        Type:   "example",
        MyMeta: map[string]interface{}{
            "author": "John Doe",
            "tags":   []string{"example", "metadata"},
        },
        // Populate other document fields as necessary
    }

    // Save the document with the custom metadata to CouchDB
    err := createDocumentWithMetadata(couchdbUrl, doc)
    if err != nil {
        fmt.Println("Error creating document:", err)
    } else {
        fmt.Println("Document created successfully")
    }
}
```

In this code snippet: - CustomDocument has a my_meta field that holds your custom metadata. - createDocumentWithMetadata serializes the document and sends an HTTP POST request to the database URL.

Remember to replace " <http://localhost:5984/mydb>" with the actual URL of your CouchDB database and update the data structure to reflect the fields that you want to include.

It's important to design your metadata, keeping in mind that you should not start the keys with an underscore, and all the data included should be intentional and relevant for your application logic or for future queries and indexing.
