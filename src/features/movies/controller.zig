const std = @import("std");
const spider = @import("spider");
const Response = spider.Response;
const Request = spider.Request;

const service = @import("service.zig");
const model = @import("model.zig");

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    return spider.chuckBerry(alloc, req, "movies/index", .{
        .query = null,
        .results = &.{},
    });
}

pub fn search(alloc: std.mem.Allocator, req: *Request) !Response {
    const query = (try req.queryParam("q", alloc));

    var search_result: ?model.MovieSearchResult = null;
    if (query) |q| {
        search_result = try service.searchMovies(alloc, req.io, q);
    }

    return spider.chuckBerry(alloc, req, "movies/search", .{
        .query = query,
        .results = if (search_result) |sr| sr.results else &.{},
    });
}

pub fn popular(alloc: std.mem.Allocator, req: *Request) !Response {
    const popular_movies = try service.getPopularMovies(alloc, req.io);

    return spider.chuckBerry(alloc, req, "movies/popular", .{
        .movies = popular_movies.results,
        .page = popular_movies.page,
        .total_pages = popular_movies.total_pages,
    });
}

pub fn movieDetails(alloc: std.mem.Allocator, req: *Request) !Response {
    const movie_id_str = req.params.get("id") orelse {
        return Response.text(alloc, "Missing movie ID");
    };

    const movie_id = std.fmt.parseInt(u32, movie_id_str, 10) catch {
        return Response.text(alloc, "Invalid movie ID");
    };

    const movie_details = try service.getMovieDetails(alloc, req.io, movie_id);

    return spider.chuckBerry(alloc, req, "movies/details", .{
        .movie = movie_details,
    });
}
