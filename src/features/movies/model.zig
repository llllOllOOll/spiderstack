const std = @import("std");

pub const Movie = struct {
    id: u32,
    title: []const u8,
    overview: []const u8,
    release_date: []const u8,
    poster_path: ?[]const u8 = null,
    backdrop_path: ?[]const u8 = null,
    vote_average: f32,
    vote_count: u32,
    popularity: f32,
};

pub const MovieDetails = struct {
    id: u32,
    title: []const u8,
    overview: []const u8,
    release_date: []const u8,
    poster_path: ?[]const u8 = null,
    backdrop_path: ?[]const u8 = null,
    vote_average: f32,
    vote_count: u32,
    popularity: f32,
    runtime: ?u32 = null,
    genres: []Genre,
    production_companies: []ProductionCompany,
};

pub const Genre = struct {
    id: u32,
    name: []const u8,
};

pub const ProductionCompany = struct {
    id: u32,
    name: []const u8,
    logo_path: ?[]const u8 = null,
    origin_country: []const u8,
};

pub const MovieSearchResult = struct {
    page: u32,
    results: []Movie,
    total_pages: u32,
    total_results: u32,
};

pub const MovieListResult = struct {
    page: u32,
    results: []Movie,
    total_pages: u32,
    total_results: u32,
};
