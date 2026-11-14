# Встроенные: полная таблица

Рабочий список для компилятора (источник — дампы и спека). README даёт
краткие таблицы для программиста — здесь полнота.

## Глобальные функции

| Группа | Вызовы |
| --- | --- |
| Проверки и размер | `len(x)`, `type(x)`, `str(x)`, `flint(x)` |
| Строки | `up(s)`, `low(s)`, `title(s)` |
| Числа | `abs(n)`, `round(n)`, `floor(n)`, `ceil(n)`, `sqrt(n)`, `min`, `max` |
| Коллекции | `sum(xs)`, `avg(xs)`, `keys(d)`, `values(d)`, `upk(coll)`, `sort(xs)`, `reverse(xs)`, `clear(coll)` |
| Высшего порядка — этап роста | `map(xs, f)`, `filter(xs, f)`, `reduce(xs, f, start)` |
| Файлы | `read_file(путь)`, `write_file(путь, текст)`, `file_exists(путь)` |
| Процесс | `args()`, `exit(код)`, `time_ms()`, `is_tty()`, `system(команда)` |
| Тестовые — с этапом тестов | `assert(условие, сообщение)`, `expect(значение)` |
| Печать и ввод | `show(шаблон)`, `show_err(шаблон)`, `input(подсказка)` |

Коротко о каждой:

- `len` — `str`: символы UTF-8, `list`/`froz`: элементы, `dict`: ключи;
- `type` — имя типа текстом: `"str"`, `"flint"`, `"bool"`, `"list"`,
  `"dict"`, `"froz"`, `"func"`, `"NONE"` или имя модели (число — это
  `"flint"`, не `"number"`);
- `str(x)` — текст значения; `flint(x)` — разбор числа: `str` → число
  (мусор → `VALUE_ERROR`), `bool` → 1/0;
- `up`/`low` — регистр: трогают латиницу и Latin-1, кириллицу **не**
  трогают; `title` — каждое слово с заглавной;
- `sum` — сумма чисел списка, пустой → `0`, проверяет и каждый элемент;
  `avg` — среднее, дробное в рамках `flint` (`31 / 8` → `3.875`);
- `min`/`max` — см. «Открытые мелочи»;
- `keys(d)` → список ключей, `values(d)` → список значений;
- `upk(coll)` — распаковка в текст без внешних скобок: `[1, "два"]` →
  `1, "два"`; у словаря — как в литерале: `имя: "Kraft"`;
- `sort`/`reverse` — **возвращают новый список** (`nums = sort(nums)`),
  по возрастанию; со строками не работают;
- `map(xs, f)` → новый список из результатов, `filter(xs, f)` →
  оставшиеся, `reduce(xs, f, start)` → свёртка (`f` — два аргумента);
  `f` — имя функции, лямбд в языке нет;
- `read_file` — нет файла → `FILE_ERROR`; `write_file` — только
  перезапись целиком, `bool`; `file_exists` → `bool`;
- `args()` — список строк: `[0]` — путь к исходнику, дальше — аргументы
  командной строки; `exit(код)`; `time_ms()` — процессорное время в
  миллисекундах; `is_tty()` → `bool` — TRUE, если stderr — терминал
  (компонент растущего xkraft: цвета ошибок только на TTY);
- `system(команда)` — POSIX-билинг (этап роста): запуск через
  `/bin/sh -c` (внутренний `system()`); код выхода 0..255, по сигналу —
  128+номер, не запустилось → -1; общий для kraftc и xkraft;
- `assert(условие, сообщение)` — `ASSERT_ERROR` при ложном условии;
  `expect(значение)` — цепочки `.equals(x)`, `.is_true()`,
  `.is_false()`, `.contains(x)`, `.is_none()`;
- `show`/`input` — печать и ввод текстового шаблона с `$` (раздел
  README «Строки и интерполяция»);
- `show_err` — как `show`, но в stderr (компонент растущего xkraft:
  ошибки компилятора уходят в тот же поток, куда kraftc пишет
  report_error); возвращает NONE.

Проверка типа — **оператор** `x is T`. Функций `is_list`/`is_dict` нет.

## Методы строки

```kraft
str stroka = "  Hello, Kraft World!  "

up(stroka)                     # → "  HELLO, KRAFT WORLD!  "
low(stroka)                    # → "  hello, kraft world!  "
title(stroka)                  # → "  Hello, Kraft World!  "

stroka.trim()                  # → "Hello, Kraft World!"
stroka.triml()                 # → "Hello, Kraft World!  "
stroka.trimr()                 # → "  Hello, Kraft World!"
"###Hello###".trim("#")        # → "Hello"

"a,b,c".part(",")              # → ["a", "b", "c"]
"hello world".part()           # → ["hello", "world"] — по пробелам
"a,b,c,d".part(",", 2)         # → ["a", "b", "c,d"] — с лимитом

stroka.preff("  Hello")        # → TRUE — начинается с...
stroka.suff("!  ")             # → TRUE — заканчивается на...

stroka.contains("Kraft")       # → TRUE
stroka.find("Kraft")           # → 9 — индекс или -1
stroka.count("l")              # → 2 — сколько раз встречается

stroka.replace("Kraft", "Python")   # → замена всех вхождений
"hello world".remove("l")      # → "heo word" — все "l"
"hello world".remove("l", 1)   # → "helo world" — первая "l"
```

У строки **нет** `join` и нет склейки `+` — только интерполяция и
`list.join(...)`. Индексы и `find` считаются в символах, не в байтах.

## Методы списка

```kraft
list nums = [3, 1, 4, 1, 5, 9, 2, 6]

len(nums)                      # → 8
sum(nums)                      # → 31
min(nums)                      # → 1
max(nums)                      # → 9
avg(nums)                      # → 3.875
upk(nums)                      # → "3, 1, 4, 1, 5, 9, 2, 6"

nums = sort(nums)              # новый список по возрастанию
nums = reverse(nums)           # новый список в обратном порядке
clear(nums)                    # → [] — очищает на месте, возвращает NONE
```

```kraft
list nums = [1, 2, 3]

nums.add(4)                    # → [1, 2, 3, 4] — в конец
nums.add(0, 0)                 # → [0, 1, 2, 3, 4] — по индексу
nums.del()                     # → удаляет последний
nums.del(0)                    # → удаляет по индексу
nums.remove(3)                 # → удаляет все вхождения 3
nums.remove(3, 1)              # → удаляет 1 вхождение
nums.contains(4)               # → TRUE
nums.count(2)                  # → 1 — сколько раз встречается
nums.index(2)                  # → 1 — индекс первого вхождения
nums.join(", ")                # → текст через разделитель
```

`add`/`del`/`remove` меняют список **на месте**, без
присваивания; `clear(nums)` — функция, тоже на месте. Срезы — как у строки.

## Методы словаря

```kraft
dict user = {name: "Alex", age: 25, city: "Moscow"}

len(user)                      # → 3
keys(user)                     # → ["name", "age", "city"]
values(user)                   # → ["Alex", 25, "Moscow"]
upk(user)                      # → name: "Alex", age: 25, ...
```

```kraft
dict user = {name: "Alex", age: 25}

user["name"]                   # → "Alex"
user["email"]                  # → NONE — нет ключа, не ошибка
user.contains("age")           # → TRUE
user.add("email", "a@b.com")   # добавить ключ или обновить значение
user.take(key)                 # значение по переменной-ключу → NONE, если нет
user.remove("age")             # → TRUE — удалить по ключу; нет ключа → FALSE
clear(user)                    # → {} — очищает на месте, возвращает NONE

dict defaults = {role: "user", active: TRUE}
dict merged = user.merge(defaults)   # → новый словарь
for k, v in user:              # перебор ключей и значений
    show($k = $v)
```

Ключ — всегда строка; в скобках bare-имя то же самое, что строка:
`user[name]` ≡ `user["name"]`. Пара `{ключ: значение}` — единственное
место со двоеточием вне блоков.

## Срезы (строки и списки)

```kraft
stroka[0..5]                   # → "  Hell" — правая граница не входит
stroka[..5]                    # → "  Hell" — левая открыта
stroka[7..]                    # → "Kraft World!  " — правая открыта
stroka[-6..]                   # → "orld!  " — отрицательный индекс
nums[1..5..2]                  # → с шагом 2
```

Обратный диапазон (`nums[3..1]`) — пустой список, не ошибка; шаг `0` —
`VALUE_ERROR`; индекс за пределами списка — `VALUE_ERROR`.

## Открытые мелочи

Решено при эмите (зафиксировано в `rules.md`, раздел «Эмит v0»):

1. `min`/`max` — поддерживаются обе формы: по списку (`max(nums)`) и по
   числам (`max(a, b)`); арность ограничена — от 1 до 9 аргументов,
   за пределами `ARGCOUNT_ERROR`.
2. `list.replace(a, b)` — заменяет первое вхождение значения `a` на `b`
   (параллельно `remove`, форма прежней таблицы — не индекс).
3. `upk(coll)` — распаковка в формате печати без внешних скобок:
   `upk([1, "два"])` → `1, "два"`; `upk(dict)` — `имя: "Kraft"` как в
   литерале. Разделитель — `", "`.
