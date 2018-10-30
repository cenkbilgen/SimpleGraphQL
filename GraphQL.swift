//
//  GraphQL.swift
//
//  Created by Cenk Bilgen on 2018-10-15.
//  Copyright © 2018 Cenk Bilgen. All rights reserved.
//

import Foundation

// Generate a simple GraphQL search based query

//////////////
// A. Summary of Usage

// To use:
// 1. a) Create a 'GraphQLSearch' object (with an array of your search constraints (matches))
//    b) Create a 'GraphQLSchema' object (with the properties you want to see)
//    c) put those two into a 'GraphQLQuery'

// 2. Setup up the shard 'GraphQLFetcher' singleton with your url and any application key

// 3. Call the generic 'fetch' function of 'GraphQLFetcher' with your 'GraphQLQuery' object. The generic parameter is your defined data type, which only must conform to Decodable.  The completion, if all goes well, will return an array of your generic Decodable types.

// Below are more details, also see the sample GraphQLQuery at the end of this file for a concrete example

//////////////
// B. Details on Creating the GraphQLQuery object

// for example
//func placesQuery(country: String) -> GraphQLQuery {
//
//  let match = GraphQLMatch(attribute: "country", op: .equals, value: country)
//
//  let search = GraphQLSearch(resource: "PLACES", matches: [match])
//
//  let schema = GraphQLSchema(items: [
//    GraphQLSchemaItem(item: "...on PlaceType", subitems: [
//      GraphQLSchemaItem(item: "name"),
//      GraphQLSchemaItem(item: "population"),
//      GraphQLSchemaItem(item: "coordinates", subitems: [
//        GraphQLSchemaItem(item: "latitude"), GraphQLSchemaItem(item: "longitude"])
//      ])
//    ])
//
//  let query = GraphQLQuery(name: "places", search: search, schema: schema)
//
//  return query
//
//}

//----------------
//---------- Generates -------->
//----------------

//query places {
//  search(
//    resource: PLACES,
//    query: { must:[
//      {match: {operator: EQ, attr: "country", value: "abc"}]}
//    )
//  {
//    count
//    results {
//      ...on PlaceType {
//      name
//      population
//      coordinates {
//        latitude
//        longitude
//       }
//    }
//  }
//}
//}



//////////////
// C. Details on the Conversion of the GraphQL response into an array of specific objects
//
// To use the results you may want to create a URLSession data task that does something like this
// in Swift based pseudo-code, "User" is your specific struct or class
// ```
//func fetch<Animal>(completion: (( [Animal]?, Error? )->Void) {
//
//  let request = URLRequest
//
//  let task = URLSession.dataTask { data, error in
//
//    var animals: [Animal]?
//
//    defer { completion(animals, error) }
//
//    // YOU SPECIFY "Animal" TYPE, must be Decodable
//    let graphQLResponse = try JSONDecoder().decode(GraphQLResponseData<Animal>.self, from: data)
//    animals = graphQLResponse.results as? [Animal]
//
//  }
//
//}
// ```
//  NOTE: Your server should respond with a GraphQL compliant response, see the GraphQLResponse class
//  but something in the form `{"data": { "search" : { "results" : [ _user json_ ] } } }`
//
//  GraphQLResponseData is a generic class, you specify the types in the result array, ie User, Animal whatever
//  but it must be decodable and you probably need an express `init(from decoder: Decoder)` if you have nested values

///////////////////////////////////////////////////////////////////////////

// MARK: Search

enum GraphQLOperator: String {
  case equals = "EQ"
  case greaterThan = "GT"
  case lessThan = "LT"
  // TODO: Add more operators
}

struct GraphQLMatch {
  
  let attribute: String
  let op: GraphQLOperator  // operator is a keyword=
  let value: String
 
  // ie {match: {operator: EQ, attr: "account_email", value: "hello@email.com"}
  
  var term: String {
    return "{match: {operator: \(op.rawValue), attr: \"\(attribute)\", value: \"\(value)\"}}"
  }
  
}

struct GraphQLSearch {

  // ie search( resource: PROFILE, query: { must:[
  //      {match: {operator: EQ, attr: "id", value: "abc"}]})
  
  // A search term needs 1. a resource, ie PROFILE, and 2. any number of GraphQLMatch terms (see above)
  
  let resource: String
  
  let matches: [GraphQLMatch]
  
  // TODO: Add these
//  let pageSize = 5
//  let page = 1
  
  var term: String {
    
    // TODO: Check for empty matches
    
    var term = "search( resource: \(resource.uppercased()), query: { must:"
    
    term += "[" + matches.map({$0.term}).joined(separator: ",") + "]"
    
    term += "} )"
    
    return term
    
  }
  
}

// MARK: Schema

struct GraphQLSchemaItem {
  // ie: just "id" or "nationality { name }"
 
  var item: String // could be "...on ProfileType" or "nationality" like
  var subitems: [GraphQLSchemaItem]?
  
  init(item: String, subitems: [GraphQLSchemaItem]? = nil) {
    self.item = item
    self.subitems = subitems
  }


  var term: String {
    
    var term = ""
    
    if let subitems = subitems {  // has subitems
    
      term += "\(item) {"
      for subitem in subitems { term += subitem.term }
      term += "}"
  
    } else {  // just one item
      
     term += item + "\n"
    
    }
    
    return term
    
  }
  
}

struct GraphQLSchema {
  
  let items: [GraphQLSchemaItem]
  
  var term: String {
    
    var term = "{count\n results {\n"
    
    for item in items {
      term += item.term
    }
    
    term += "}" // results
    term += "}" // [schema]
    
    return term
    
  }
  
}

// MARK: Complete Query (Search + Schema)

struct GraphQLQuery {
  
  let name: String
  let search: GraphQLSearch
  let schema: GraphQLSchema
  
  var term: String {
    
    var term = "query \(name) {"
    
    term += search.term
    
    term += schema.term
    
    term += "}" // query
    
    print(term)
    
    return term
    
  }
  
  func jsonBody() throws -> Data {
    
//    let json: [String: String?] = ["query": self.term, "variables": nil] // IMPORTANT: otherwise will 500
//    let data = try JSONEncoder().encode(json)
    
    let json: [String: Any] = ["query": self.term, "variables": NSNull()]
    let data = try JSONSerialization.data(withJSONObject: json, options: [])
    
    return data

  }
  
}

// GraphQL Response

// GraphQL always wraps it's resposne in
// "data : { search : { results [ 'what we want' ] }"
// This makes confirming to Decodable protocol kind of messy because we are adding useless properties like data and result, or
// otherwise we need create a really customized initializer (when most times we wouldn't need one at all if dealing with native data types

 // top level { "data": {...} }
class GraphQLResponseData<T: Decodable>: Decodable {

  let results: [Decodable]
  fileprivate let data: GraphQLResponseSearch
  
  private enum CodingKeys: String, CodingKey {  // implicitly added anyway, but here for possible expansion
    case data
  }
  
  required init(from decoder: Decoder) throws {
    
    do {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      let data = try values.decode(GraphQLResponseSearch.self, forKey: .data)

      self.data = data
    
      // bubble the reults up to the top level
     self.results = data.search.results
      
    } catch {
      print("json error: \(error)")
      throw error
    }
    
  }
  
  // second level {"search": { ...} }
  fileprivate class GraphQLResponseSearch: Decodable {
    
    var search: GraphQLResponseResults
  
    private enum CodingKeys: String, CodingKey {
      case search
    }
    
    required init(from decoder: Decoder) throws {
      
      do {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.search = try values.decode(GraphQLResponseResults.self, forKey: .search)
      } catch {
        print("json error: \(error)")
        throw error
      }

    }
    
    // third level {"results": [T] }
    fileprivate class GraphQLResponseResults: Decodable {
      
      var results: [Decodable]
      var count: Int
      
      private enum CodingKeys: String, CodingKey {
        case results
        case count
      }
      
      required init(from decoder: Decoder) throws {
        
        do {
        
          let values = try decoder.container(keyedBy: CodingKeys.self)

          self.count = try values.decode(Int.self, forKey: .count)
        
          var resultsValues = try values.nestedUnkeyedContainer(forKey: .results)
        
          var results: [Decodable] = []
          while resultsValues.isAtEnd == false {
            let result = try resultsValues.decode(T.self)
            results.append(result)
          }
        
          self.results = results
          
        } catch {
          print("json error: \(error)")
          throw error
        }
        
      }
      
    }
    
  }
  
  
}

class GraphQLFetcher {
  
  static let shared = GraphQLFetcher()
  
  let url = URL(string: "https://rest.restservice.com/graphql/")!  // set this to your server
  var applicationKey: String?  // may need to set this
  
  func fetch<T: Decodable>(query: GraphQLQuery, completion: @escaping ([T]?, Error?) -> Void) {
  
    var request = URLRequest(url: url)
    if let applicationKey = applicationKey {
      request.addValue(applicationKey, forHTTPHeaderField: "X-Application-Key")
    }
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
      let data = try query.jsonBody()
      request.httpBody = data
      request.httpMethod = "POST"
    } catch {
      completion(nil, error)
      return
    }
    
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      
      var results: [T]?
      var taskError: Error? = error
      
      defer {
        completion(results, taskError)
      }
      
      guard error == nil else {
        print(error!.localizedDescription)
        return
      }
      
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      
      let responseBody = String(data: data ?? Data(), encoding: .utf8)
      print(responseBody ?? "")
      
      guard statusCode == 200 else {
        print("Fetch returned \(statusCode)")
        return
      }
      
      guard let data = data else {
        print("No data returned")
        return
      }
      
      do {
        
        let graphQLResponse = try JSONDecoder().decode(GraphQLResponseData<T>.self, from: data)
        results = graphQLResponse.results as? [T]
        
      } catch {
        
        taskError = error
        
      }
      
      // go to defer
      
    }
    
    task.taskDescription = "graphql request \(task.taskIdentifier)"
    
    task.resume()
    
  }
  
  // MARK: EXAMPLE QUERY
  
  fileprivate func placeQuery(country: String, minimumPopulation: Int) -> GraphQLQuery {
    
    let match1 = GraphQLMatch(attribute: "country", op: .equals, value: country)
    let match2 = GraphQLMatch(attribute: "population", op: .greaterThan, value: String(minimumPopulation)) // everything's a string
    
    // search part
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
    
    let query = GraphQLQuery(name: "place", search: search, schema: schema)
    
    return query
    
  }
  
}
    


