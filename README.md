# SimpleGraphQL
A simple GraphQL query generator and fetcher in Swift

Just add this one file to your project to create simple GraphQL search based queries and fetch them from your server directly as an array of your own custom objects (they must only conform to `Decodable`). To get it to work it will require some modification to match your particular GraphQL server's setup.

See the code comments for usage.

```
  fileprivate func placeQuery(country: String, minimumPopulation: Int) -> GraphQLQuery {
    
    // search part
    let match1 = GraphQLMatch(attribute: "country", op: .equals, value: country)
    let match2 = GraphQLMatch(attribute: "population", op: .greaterThan, value: String(minimumPopulation)) // everything's a string
    
    let search = GraphQLSearch(resource: "PLACES", matches: [match1, match2])
    
    // schema part
    let schema = GraphQLSchema(items: [
      GraphQLSchemaItem(item: "...on PlaceType", subitems: [
        GraphQLSchemaItem(item: "name"),
        GraphQLSchemaItem(item: "population"),
        GraphQLSchemaItem(item: "coordinates", subitems: [
          GraphQLSchemaItem(item: "latitude"),
          GraphQLSchemaItem(item: "longitude")])
        ])
      ])
    
    // search + schema => query
    let query = GraphQLQuery(name: "place", search: search, schema: schema)
    
    return query
    
  }
  
}
```

```
class Place: Decodable {
  //...
}
```

```
let query = placeQuery(country: "Canada", population: 10000)
GraphQLFetcher.shared.fetch(query: query) { (places: [Place]?, error) in
  // ...
}
```
      
