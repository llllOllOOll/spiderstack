# ArrayList no Zig 0.16.x - Guia Completo

## Sumário

1. [O que é ArrayList?](#o-que-é-arraylist)
2. [Inicialização](#inicialização)
3. [Adicionar Itens](#adicionar-itens)
4. [Acessar Itens](#acessar-itens)
5. [Remover Itens](#remover-itens)
6. [Cleanup e Memória](#cleanup-e-memória)
7. [Casos Especiais: Ponteiros e Strings](#casos-especiais-ponteiros-e-strings)
8. [Detectando Memory Leaks](#detectando-memory-leaks)
9. [Builtin Allocator do Processo](#builtin-allocator-do-processo)
10. [Melhores Práticas](#melhores-práticas)

---

## O que é ArrayList?

`ArrayList` é um array dinâmico growable no Zig, similar ao `std::vector` do C++ ou `Vec<T>` do Rust.

- **Armazena**: Um buffer contínuo de memória
- **Growable**: Pode expandir automaticamente quando necessário
- **Slice de acesso**: Acesse elementos via `list.items`

---

## Inicialização

### Opção 1: `.empty` (Recomendado para iniciantes)

```zig
var lista: std.ArrayList(u32) = .empty;
```

- Cria um ArrayList vazio
- Cresce dinamicamente conforme você adiciona itens
- Simples, sem necessidade de saber o tamanho antecipadamente

### Opção 2: `initCapacity` (Melhor performance)

```zig
var lista = try std.ArrayList(u32).initCapacity(allocator, 100);
defer lista.deinit(allocator);
```

- Pré-aloca memória para 100 elementos
- Evita realocações frequentes
- Use quando souber o tamanho aproximado

### Opção 3: Managed (Deprecated - ainda funciona)

```zig
var lista = std.ArrayList(u32).init(allocator);
defer lista.deinit();
```

- Versão antiga que armazena allocator internamente
- **Não recomendado** - será removido em futuras versões

---

## Adicionar Itens

### Um item

```zig
try lista.append(allocator, 10);
try lista.append(allocator, 20);
```

### Múltiplos itens

```zig
try lista.appendSlice(allocator, &[_]u32{ 30, 40, 50 });
```

### Sem allocator (precisa garantir capacidade)

```zig
lista.appendAssumeCapacity(10);
lista.appendAssumeCapacity(20);
```

### Adicionar N vezes

```zig
try lista.appendNTimes(allocator, 0, 100); // adiciona 100 zeros
```

---

## Acessar Itens

```zig
// Por índice
const primeiro = lista.items[0];
const ultimo = lista.items[lista.items.len - 1];

// Com segurança
if (lista.items.len > 0) {
    const item = lista.getLast();
}

// Iterar
for (lista.items) |item| {
    std.debug.print("{}\n", .{item});
}

// Com índice
for (lista.items, 0..) |item, i| {
    std.debug.print("[{}] = {}\n", .{ i, item });
}
```

---

## Remover Itens

```zig
// Remove e retorna o último
const removido = lista.pop();

// Remove no índice (preserva ordem - O(n))
const item = lista.orderedRemove(3);

// Remove no índice (swap remove - O(1), não preserva ordem)
const item2 = lista.swapRemove(3);

// Limpa mas mantém capacidade
lista.clearRetainingCapacity();

// Limpa e libera memória
lista.clearAndFree(allocator);
```

---

## Cleanup e Memória

### Regra de Ouro: SEMPRE use defer

```zig
fn exemplo1() !void {
    var lista: std.ArrayList(u32) = .empty;
    defer lista.deinit(allocator);  // ← OBRIGATÓRIO!

    try lista.append(allocator, 10);
    // ...
} // aqui o defer chama deinit automaticamente
```

### Por que não precisa iterar para tipos primitivos?

```zig
var lista: std.ArrayList(u32) = .empty;
defer lista.deinit(allocator);

try lista.append(allocator, 10);
// A memória é apenas: [u32, u32, u32, ...]
// Só precisa deinit() para liberar o buffer
```

O `deinit()` libera **todo o buffer** de uma vez. Não há ponteiros internos para liberar individualmente.

---

## Casos Especiais: Ponteiros e Strings

### Quando você PRECISA iterar

Quando os itens do ArrayList **contêm ponteiros** para memória alocada separadamente:

```zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // ArrayList de strings (que são ponteiros!)
    var lista: std.ArrayList([]u8) = .empty;
    defer {
        // ← PRECISA ITERAR! Cada string é um ponteiro alocado
        for (lista.items) |str| {
            allocator.free(str);
        }
        lista.deinit(allocator);
    }

    // Cada string precisa ser alocada separadamente
    const s1 = try allocator.dupe(u8, "Pão");
    const s2 = try allocator.dupe(u8, "Leite");
    const s3 = try allocator.dupe(u8, "Ovos");

    try lista.append(allocator, s1);
    try lista.append(allocator, s2);
    try lista.append(allocator, s3);
}
```

### De structs com campos alocados

```zig
const Item = struct {
    nome: []u8,
    valor: i32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var lista: std.ArrayList(Item) = .empty;
    defer {
        // Cada Item tem um campo 'nome' que é ponteiro!
        for (lista.items) |item| {
            allocator.free(item.nome);
        }
        lista.deinit(allocator);
    }

    const nome = try allocator.dupe(u8, "Teste");
    try lista.append(allocator, .{ .nome = nome, .valor = 42 });
}
```

### Resumo: Quando iterar?

| Tipo do Item | Precisa Iterar? | Motivo |
|--------------|-----------------|--------|
| `u32`, `i64`, `f64` | ❌ Não | Valor direto, não ponteiro |
| `bool`, `enum` | ❌ Não | Valor direto |
| `[]u8` (string) | ⚠️ Depende | Ver abaixo |
| `[]T` (slice) | ⚠️ Depende | Ver abaixo |
| `*T` (pointer) | ⚠️ Depende | Ver abaixo |
| `struct { campo: []u8 }` | ⚠️ Depende | Ver abaixo |
| `struct { campo: i32 }` | ❌ Não | Campo é valor |

### ArenaAllocator: A SOLUÇÃO DEFINITIVA

A **`ArenaAllocator`** resolve o problema de vazamento de memória para **qualquer tipo de item**, incluindo strings e ponteiros!

**Com Arena: NÃO precisa iterar!**

```zig
const std = @import("std");

pub fn main() !void {
    // Arena = um "pool" de memória, libera tudo de uma vez no final
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();  // ← Libera TUDO automaticamente!
    
    const allocator = arena.allocator();

    // ArrayList de strings - mesmo caso "complicado"
    var lista: std.ArrayList([]u8) = .empty;
    defer lista.deinit(allocator);  // ← Só isso! Sem loop!

    // Cada string é alocada separadamente NA ARENA
    const s1 = try allocator.dupe(u8, "Pão");
    const s2 = try allocator.dupe(u8, "Leite");
    const s3 = try allocator.dupe(u8, "Ovos");

    try lista.append(allocator, s1);
    try lista.append(allocator, s2);
    try lista.append(allocator, s3);

    // NÃO PRECISA de for loop para free!
    // arena.deinit() libera TUDO de uma vez
}
```

**Por que funciona?**

```
┌─────────────────────────────────────┐
│           ARENA                      │
│  ┌─────────────────────────────┐    │
│  │  Pool de memória único       │    │
│  │                             │    │
│  │  [s1="Pão"] [s2="Leite"]   │    │
│  │  [s3="Ovos"] [buffer list] │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  arena.deinit() → free(TUDO)        │
└─────────────────────────────────────┘
```

A Arena aloca tudo de um mesmo "pool". Quando você chama `deinit()`, ela libera **todo o pool de uma vez**, não importa quantas alocações foram feitas dentro.

### Quando usar o que?

| Cenário | Recomendado | Por quê |
|---------|-------------|---------|
| Programa simples/main | `ArenaAllocator` | Não precisa pensar em leaks |
| Biblioteca | Receba allocator como parâmetro | Usuário escolhe |
| Tests | `testing.allocator` | Já detecta leaks automaticamente |
| Performance crítica | `GeneralPurposeAllocator` | Mais controle |

### Sem Arena (precisa iterar)

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer std.debug.assert(gpa.deinit() == .ok);
const allocator = gpa.allocator();

var lista: std.ArrayList([]u8) = .empty;
defer {
    for (lista.items) |str| {
        allocator.free(str);  // ← PRECISA disso com GPA!
    }
    lista.deinit(allocator);
}
```

**Resumo**: Arena = "deixa que o Arena gerencia, eu não quero saber de leaks" 😄

---

## Detectando Memory Leaks

### Método 1: Testing Allocator (para testes)

```zig
test "meu teste" {
    var lista: std.ArrayList(u32) = .empty;
    defer lista.deinit(std.testing.allocator);

    try lista.append(std.testing.allocator, 10);

    // Se houver leak, o teste falha automaticamente
}
```

### Método 2: GeneralPurposeAllocator (para programas)

```zig
const std = @import("std");

pub fn main() !void {
    // 1. Cria o GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    // 2. Obtém o allocator
    const allocator = gpa.allocator();

    // 3. Usa normalmente
    var lista: std.ArrayList(u32) = .empty;
    defer lista.deinit(allocator);

    try lista.append(allocator, 10);

    // 4. Verifica leaks ANTES de finalizar
    const leaks = gpa.detectLeaks();
    if (leaks > 0) {
        std.debug.print("{} memory leaks detected!\n", .{leaks});
    }

    // 5. Finaliza e verifica
    const result = gpa.deinit();
    std.debug.assert(result == .ok);
}
```

### Método 3: ArenaAllocator (solução automática)

A Arena é a solução mais simples - você não precisa dar free em nada:

```zig
const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();  // ← Libera TUDO de uma vez!

    const allocator = arena.allocator();

    // Não precisa de free individual!
    var lista: std.ArrayList([]u8) = .empty;
    defer lista.deinit(allocator);

    const s1 = try allocator.dupe(u8, "Pão");
    const s2 = try allocator.dupe(u8, "Leite");

    try lista.append(allocator, s1);
    try lista.append(allocator, s2);

    // Tudo é liberado automaticamente pelo arena.deinit()
}
```

---

## Builtin Allocator do Processo

O Zig já vem com um allocator disponível automaticamente:

### page_allocator

```zig
const allocator = std.heap.page_allocator;
// Simples, mas não recomendado para uso geral
```

### ArenaAllocator do processo

Na função `main()`, você pode usar:

```zig
pub fn main() !void {
    // Arena alocada no heap do processo
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Agora usa normalmente
    var lista: std.ArrayList(u32) = .empty;
    defer lista.deinit(allocator);

    try lista.append(allocator, 1);
    // ...
}
```

### Para bibliotecas (receba allocator como parâmetro)

```zig
pub fn processaLista(allocator: std.mem.Allocator) !void {
    var lista: std.ArrayList(u32) = .empty;
    defer lista.deinit(allocator);

    try lista.append(allocator, 10);
    // ...
}
```

---

## Melhores Práticas

### ✅ Faça

```zig
// 1. Use defer SEMPRE
var lista: std.ArrayList(u32) = .empty;
defer lista.deinit(allocator);

// 2. Use .empty para casos simples
var lista2: std.ArrayList(u32) = .empty;

// 3. Use initCapacity se souber o tamanho
var lista3 = try std.ArrayList(u32).initCapacity(allocator, 100);
defer lista3.deinit(allocator);

// 4. Use Arena para evitar leaks
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const allocator = arena.allocator();

// 5. Passe allocator como parâmetro em funções
fn minhaFuncao(allocator: std.mem.Allocator, lista: *std.ArrayList(u32)) !void {
    try lista.append(allocator, 10);
}
```

### ❌ Não Faça

```zig
// 1. Não esqueça o defer
var lista: std.ArrayList(u32) = .empty;
try lista.append(allocator, 10);
// FUGA! Leak!

// 2. Não itere desnecessariamente (só para tipos primitivos)
var lista: std.ArrayList(u32) = .empty;
defer lista.deinit(allocator);
// NÃO precisa de for loop aqui!

// 3. Não misture allocators
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const a1 = gpa.allocator();
const a2 = std.heap.page_allocator; // diferente!
// Use sempre o mesmo

// 4. Não use Managed (deprecated)
var lista = std.ArrayList(u32).init(allocator); // antigo
defer lista.deinit(); // sem allocator parameter
```

---

## Resumo Visual

```
┌─────────────────────────────────────────────────────────────┐
│                    CRIAÇÃO                                  │
├─────────────────────────────────────────────────────────────┤
│  .empty                          → Sem alocação            │
│  initCapacity(alloc, n)         → Pré-aloca n elementos   │
│  Managed.init(alloc)             → Deprecated              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    USO                                      │
├─────────────────────────────────────────────────────────────┤
│  append(alloc, item)         → Adiciona 1                  │
│  appendSlice(alloc, &[])     → Adiciona múltiplos          │
│  items[idx]                  → Acessa                      │
│  pop()                       → Remove último               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    LIMPEZA                                  │
├─────────────────────────────────────────────────────────────┤
│  deinit(alloc)                → Libera buffer              │
│  for(items) alloc.free()       → Libera ITENS (se ponteiro)│
│  arena.deinit()                → Libera TUDO                │
└─────────────────────────────────────────────────────────────┘
```

---

## Referência Rápida

```zig
// Completo
const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lista: std.ArrayList(u32) = .empty;
    defer lista.deinit(allocator);

    try lista.append(allocator, 1);
    try lista.append(allocator, 2);
    try lista.appendSlice(allocator, &[_]u32{ 3, 4, 5 });

    for (lista.items, 0..) |item, i| {
        std.debug.print("[{}] = {}\n", .{ i, item });
    }

    const ultimo = lista.pop();
    std.debug.print("Removido: {}\n", .{ultimo});
}
```
