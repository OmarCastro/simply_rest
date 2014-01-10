library serverRouter;
import 'dart:io';

abstract class _Endpoint{
  List<String> patternSegments;
  Function handler;
  _Endpoint(String pattern,this.handler):
    patternSegments = pattern.split("/")..removeWhere((str)=>str.trim().isEmpty);
  bool parse(HttpRequest req, Map<String,String> map);
}


class _Route extends _Endpoint{
  _Route(String pattern,Function handler):super(pattern,handler);
  
  bool parse(HttpRequest req, Map<String,String> map){
    map.clear();
    List<String> segments = req.uri.pathSegments;
    if(segments.length != patternSegments.length) return false;
    for(int i=0;i < segments.length;++i){
      if(patternSegments[i].startsWith(":")){
        map[patternSegments[i].substring(1)] = segments[i];
      } else if(patternSegments[i] != segments[i]){
        return false;
      }
    }
    return true;
  }
  
  String toString()=>" ROUTE /"+patternSegments.join("/");

}

class _FileDir extends _Endpoint{
  List<String> extensions;
  _FileDir(String pattern,String stringPath, this.extensions):
    super(pattern,_serveFile(stringPath));
  
  bool parse(HttpRequest req, Map<String,String> map){
    map.clear();
    List<String> segments = req.uri.pathSegments;
    if(segments.length <= patternSegments.length) return false;
    if(extensions == null || extensions.any((str)=>segments.last.endsWith(str))){
      for(int i=0;i < patternSegments.length;++i){
        if(patternSegments[i] != segments[i]){
          return false;
        }
      }
      return true;
    } else {
      return false;
    }
    

  }
  String toString()=>" FILE /"+patternSegments.join("/");

  static Function _serveFile(String stringPath)=>(HttpRequest request,_){
    Rest.serveFile((stringPath == null)?request.uri.path:stringPath,request);
  };
}


class Rest{
  static const String GET = "GET";
  static const String PUT = "PUT";
  static const String POST = "POST";
  static const String DELETE = "DELETE";
  static String basePath;  
  Map<String,List<_Endpoint>> routeMap = {"GET":[],"POST":[],"DELETE":[],"OPTIONS":[]};
  /**
   * this is the error 404 handler by default it sends
   * to the client a "Not Found"
   * 
   * the HttpRequest in the handler has the HttpStatus defined as NOT_FOUND
   * so theres no need to redefine it at the start of the function
   */
  static Function error404Handler = (HttpRequest req){ 
    req.response.write("Not Found");
    req.response.close();
  };
  Rest([String basePath]){
    Rest.basePath = (basePath == null)?Directory.current.path:basePath;
    }
  ///creates a [handler] for a GET request with [url]
  void get(String url,void handler(HttpRequest req, Map seg))=>routeMap[GET].add(new _Route(url,handler));
  ///creates a [handler] for a POST request with [url]
  void post(String url,void handler(HttpRequest req, Map seg))=>routeMap[POST].add(new _Route(url,handler));
  ///creates a [handler] for a DELETE request with [url]
  void delete(String url,void handler(HttpRequest req, Map seg))=>routeMap[DELETE].add(new _Route(url,handler));
  ///creates a [handler] for a PUT request with [url]
  void put(String url,void handler(HttpRequest req, Map seg))=>routeMap[PUT].add(new _Route(url,handler));
  ///creates a handler for a [url] that serves files in a directory, can be filtered with
  ///the [extensions]   void file(String url,{String path ,List<String> extensions})=>routeMap[GET].add(new _FileDir(url,path,extensions));

  static void serveFile(String path,HttpRequest request){
    final File file = new File(basePath+path);
    file.exists().then((bool found) {
      if (found) {
        print("file found; sending ${file.path}");
        file.openRead().pipe(request.response).catchError((e) {print(e); });
      } else {
        _send404(request);
      }
    }); 
  }
  
  static void _send404(HttpRequest req){
    req.response.statusCode = HttpStatus.NOT_FOUND;
    error404Handler(req);
  }

  void handle(HttpRequest req){
    print("new ${req.method} ${req.uri.path} handle");
    List<_Endpoint> routes = routeMap[req.method];
    if(routes == null){
      return _send404(req);
    } else{
      Map<String,String> map = new Map();
      for(_Endpoint route in routes){
        if(route.parse(req, map)){
          print("running route $route");
          return route.handler(req,map);
        }
      }
      _send404(req);
    }
  }
  
  void startServer(dynamic address, int port, {int backlog: 0}){
    HttpServer.bind(address, port, backlog: backlog).then((server) {
      print("server started on adress $address:$port");
      server.listen((HttpRequest request)=>handle(request));
    }); 
  }
}
