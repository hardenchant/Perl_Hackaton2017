# Server protocol

## Base command packet
```js
{
    "v"    : 1,
    "cmd"  : "AUTH",
    "data" : {}
    /* "seq" : num? */
}
```

## Base event packet
```js
{
    "v"     : 1,
    "event" : "MESSAGE",
    "date"  : 1490644008,
    "data"  : { "text":"Hello!" },

    "from" : "username", /* opt */
    "to"   : "@room",    /* opt */
    "to"   : "username", /* opt */
    /* "seq" : num? */
}
```

---

## Requests
- AUTH (nick, [ password ]) # Аутентификация на сервере
    + NICK
- REGISTER (password) # Установка/смена пароля
    + OK
    + ERROR
- INFO (nickname)
    + OK: User information
    + ERROR: User not found
- MSG ( to, text ) + (on server: from, date )
    + Запоминать в клиенте последнего получателя

## Room requests

- MEMBERS (@room)
- JOIN (@room)
- PART (@room)
- KICK (@room, user)


## Responses
- OK
- ERROR: error, text

## Events
- MESSAGE: from, to, date, text
    + to: user
    + to: @room
- NICK: nick
- JOIN: room

По дефолту присоединяемся к @all


---

# Hello v1 Request

```js
{
    "v"    : 1,
    "cmd"  : "HELLO",
    "data" : {
        "nick" : "NickName"
    }
},
```

---

# Hello v2

```js
{
    "v"    : 2,
    "cmd"  : "HELLO",
    "data" : {
        "nick" : "NickName",
        "password": "..."
    }
},
```

----

```
User1 -> @Room1: MSG(to => "@Room1", text => "xxx");
Server -> User2: MESSAGE: from => User1, to => "@Room1", text => "xxx";
```

```
User1 -> @Room1: MSG(to => "@Room1", text => "User2: xxx");
Server -> User2: MESSAGE: from => User1, to => "@Room1", text => "User2: xxx";
```

```
User1 -> User2: MSG(to => "User2", text => "xxx");
Server -> User2: MESSAGE: from => User1, to => User2, text => "xxx";
```









