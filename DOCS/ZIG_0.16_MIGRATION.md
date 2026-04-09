# Zig 0.16 Migration Notes

## ArrayList API Changes

### Initialization
The `ArrayList` API has changed in Zig 0.16. Empty initialization now uses `.empty` instead of `{}`.

**Old (deprecated):**
```zig
var list = std.ArrayList(T){};
var list = std.ArrayList(T).init(allocator);
```

**New:**
```zig
var list: std.ArrayList(T) = .empty;
var list = try std.ArrayList(T).initCapacity(allocator, capacity);
```

### ArrayListUnmanaged
Similarly, `ArrayListUnmanaged` requires explicit struct fields:

**Old (deprecated):**
```zig
var arr = std.ArrayListUnmanaged(T){};
```

**New:**
```zig
var arr = std.ArrayListUnmanaged(T){ .items = &.{}, .capacity = 0 };
```

## Spider Framework Updates

### server.zig
- Line 73: `net.IpAddress.listen(address, ...)` → `net.IpAddress.listen(&address, ...)`
- Lines ~312-338: Added keep_alive logic to fix POST/PUT without Content-Length

### pg.zig
- Line 568: `var conn` → `const conn` (unused variable)

### form.zig
- Lines 84, 112, 122: `std.ArrayListUnmanaged(T){}` → `std.ArrayListUnmanaged(T){ .items = &.{}, .capacity = 0 }`

### web.zig (Response.redirect)
- Added `Content-Length: 0` and `Connection: close` headers for redirects

## Content-Length Handling

### POST/PUT without Content-Length
The Zig std HTTP server has strict assertions requiring `Content-Length` or `Transfer-Encoding` headers for POST/PUT requests. Spider handles this automatically:

1. **server.zig**: When request has no Content-Length, sets `keep_alive: false` and adds `Connection: close` header
2. **web.zig**: Response.redirect() adds Content-Length: 0 and Connection: close

This prevents the server from panicking in `discardBody()`.

### Application Level (auth middleware)
The auth middleware returns 400 Bad Request with explanatory message when POST/PUT is sent without Content-Length.
