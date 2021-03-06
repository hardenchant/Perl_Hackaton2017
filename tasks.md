# Серверные задачи

Поддержка авторизации
-----------
Нужно модифицировать протокол таким образом, что бы при подключении к серверу, клиент кроме ника передавал еще и пароль.<br>
При первом подключении к серверу с некоторым ником, сервер должен запоминать этот ник в связке с паролем. При последующих попытках подключения с этим ником, если пароль совпадает с сохраненным на сервере, то новый клиент подключается, а старый с таким же ником (если подключен) - отключается.<br>
Если при подключении обнаруживается клиент, подключеный без пароля, то его так же отключаем от сервера.<br>
У кого пароль, то и прав! ;)<br>
**ВАЖНО!!!** Нужна совместимость со старым протоколом. Клиенты, ничего не знающие про новый протокол с паролем, пострадать не должны!
Требуется поддержать следующие команды (детальное описание формата смотри в ```client-commands.md```): 
```
/nick <username> <pass>
```

Комнаты
-----------
Поддержать создание отдельных комнат. Все сообщения отправляемые в комнату должны доставляться только тем клиентам, которые к этой комнате подключены.<br>
Комната созается в тот момент, когда кто то пытается подключиться к несуществующей комнате, и уничтожается, когда ее покидает последний участник.<br>
Требуется поддержать следующие команды (детальное описание формата смотри в ```client-commands.md```): 
```
/join
/leave
/part
/room 
/title 
/members
/msg #<roomname>
```

Приватные сообщения
-----------
Поддержать отправку личных сообщений - сообщений, которые доставляются только указанному участнику чата. Комнаты (если таковые реализовны) не должны влиять на доставку таких сообщений.<br>
Требуется поддержать следующие команды (детальное описание формата смотри в ```client-commands.md```): 
```
/msg @<nick>
```

Роли
-----------
Поддержать систему ролей.<br>
Возможные роли:
*  Оператор - суперпользователь, может назначать/отбирать все роли, кроме "Оператор". Указывается в конфиге сервера при старте.
*  Администратор - может давать/отбирать роли модератора участникам (кроме админов и оператора).
*  Модератор - может давать/забирать право отправлять сообщения "Участникам".
*  Участник - не имеет никаких привилегий.

Все права наследуются (т.е. "Оператор" обладает в том числе правами "Модератора" и "Администратора").<br>
Каждый участник может иметь только одну роль!<br>
Требуется поддержать следующие команды (детальное описание формата смотри в ```client-commands.md```): 
```
/grant
/mute
/kick
/ban
/unban
/mode
```

Рейтлимиты
-----------
Не даем пользователям спамить в чат. Блокируем доставку сообщений от участника (не зависимо от роли, приватности, комнаты), если он сделал более **N** (задается при старте сервера через конфиг) запросов в минуту. В случае срабатывания лимита отправляем участнику сообщение об этом.<br>
Блокировка накладывается на **M** минут (задается при старте сервера через конфиг), после чего снимается и пользователь может снова писать в чат.

Autokick
-----------
Поддержать автоматическое отключение от чата клиентов, которые бездействуют более **M** минут (задается при старте сервера через конфиг).<br>
При отключении отправляем участнику сообщение об этом.


# Клиентские задачи (боты)

Бот - это обычный клиент для сервера, который умеет анализировать поток сообщений в чате и, на основе этого анализа, что либо печатать в чат.
Бот - это обычный участник чата, поэтому у него как и пользователя есть **nick**.
Так же у каждого бота должен быть определен **bot_id**, который указан в описании задачи (это требуется для автоматизированной проверки работоспособности бота).
Каждый бот должен уметь перехватывать в чате специальную команду ```!who```. В ответ на эту команду бот должен ответить отправителю команды сообщение ```i am <bot_id>```.
Например:
```bash
@monitor > !who
@calculator_bot > i am calculator
@perldoc_bot > i am perldoc
...
```

Боты могут проявлять активность двух видов:
1. по требованию со стороны других участников чата
1. автоматически (например, печатать что то раз в минуту в чат)

В первом случае, бот ждет в чате сообщения, адресованного лично ему. И если это сообщение является допустимой командой (см. описание конктретных ботов) - выводит в чат результат обработки команды, в виде сообщения адресованном запрашивающему.
Наример, как может выглядеть общение с ботом калькулятором:
```bash
@vasya > @calculator_bot 2 + 2 * 4
@calculator_bot > @vasya 10
```
Т.е. если у нас есть бот с ником *calculator_bot*, то он должен встретив в чате сообщение ```@calculator_bot 2 + 2 * 4``` от пользователя *vasya*, отправить этому пользователю сообщение  ```@vasya 10```.

**Важно!** Все команды и ответы должны строго соответствовать описанному в заданиях формату!
**Важно!** Скрипт с ботом должен иметь имя, такое же как и **bot_id**!

#### Обозначения
```<user_nick>``` - ник пользователя, отправившего запрос<br/>
```<bot_nick>``` - ник бота

<br><br><br>
Калькулятор
---------------
Бот для решения простейших арифметических выражений. Калькулятор должен поддерживать операции: ```+ - * / ^```. В качестве операндов могут выступать десятичные числа (в том числе десятичные дроби и отрицательные числа).
Ответом на выражение может быть десятичное число или ```NaN```, если результат не определен.

#### bot_id
```
calculator
```

#### Формат команд
```
@<bot_nick> <expression>
```

#### Формат ответа
```
@<user_nick> <expression> = <expression_evaluation_result>
```

#### Пример
```bash
@vasya > @calculator_bot 1 + 2 * 3
@calculator_bot > @vasya 1 + 2 * 3 = 7
```

<br><br><br>
Вывод perldoc
---------------
Бот должен уметь выводить в чат кусочек документации **perldoc**. Конкретно, требуется выводить первый абзац (до первой пустой строки) раздела **DESCRIPTION**. Из текста нужно удалить все переводы строк и схлопнуть все последовательности пробелов и табуляций до одного пробела!

#### bot_id
```
perldoc
```

#### Формат команд
```
@<bot_nick> <perldoc_part_name>
```

#### Формат ответа
```
@<user_nick> <perldoc_part_name> DESCRIPTION: <text_without_new_lines_and_logn_spaces>
```

#### Пример
```bash
@vasya > @perldoc_bot perlsyn
@perldoc_bot > @vasya perlsyn DESCRIPTION: A Perl program consists of a sequence of declarations and statements which run from the top to the bottom. Loops, subroutines, and other control structures allow you to jump around within the code.
```

<br><br><br>
Случайные цитаты с bash.im
---------------
Бот должен выводить в чат случайную цитату из http://bash.im/rss/ один раз в минуту. Из текста нужно удалить все переводы строк и схлопнуть все последовательности пробелов и табуляций до одного пробела! Так же не надо выводить тег **CDATA**!

#### bot_id
```
bashim
```

#### Формат команд
```
не поддерживаются
```

#### Формат ответа
```
New from bash.im: <title>: <description>
```

#### Пример
```bash
@bashim_bot > New from bash.im: Цитата #444050: xxx: на проезжей части натуральный каток, машина виляет, водила даже по телефону не говорит — самому страшно
```

#### Рекомендуемые модули
``` 
AnyEvent::HTTP
LWP::UserAgent
XML::Fast
XML::RSS::Parser::Lite
```

<br><br><br>
Фортунки
---------------
Бот должен выводить в чат результат выполения программы ```fortune``` один раз в минуту. Из текста нужно удалить все переводы строк и схлопнуть все последовательности пробелов и табуляций до одного пробела!

#### bot_id
```
fortune
```

#### Формат команд
```
не поддерживаются
```

#### Формат ответа
```
Fresh fortune: <text>
```

#### Пример
```bash
@fortune_bot > Fresh fortune: Academicians care, that's who.
```

<br><br><br>
Напоминатор
-----------
Бот для напоминаний о событиях. Пользователь может отправить боту команду, содержащую дату, время и сообщение, после чего бот в обозначенный день и час, должен вывести в чат указанное сообщение адресованное пользователю.
Дата и время должны быть в формате: ```<dd/mm/yyyy> <hh:mm>``` (без секунд).
**Важно:** бот отвечает не сразу, а только в обозначенное время! 

#### bot_id
```
alarm
```

#### Формат команд
```
@<bot_nick> <datetime> <message>
```

#### Формат ответа
```
@<user_nick> ALARM! Now is <datetime>: <message>
```

#### Пример
```bash
@vasya > @alarm_bot 29/03/2017 21:00 Хакатон закончился!
@alarm_bot > @vasya ALARM! Now is 29/03/2017 21:00: Хакатон закончился!
```

#### Рекомендуемые модули
``` 
POSIX::strptime
Time::Local
```

<br><br><br>
Конвертор валют
-----------
Бот для конвертации в рубли из валюты. Принимает от пользователя в сообщении сумму и валюту, из которой необходимо провести конвертацию. Должен уметь проводить конвертацию на указанную дату. Если дата не укзазана, то считается что указан текущий день.
Валюта в запросе может быть указана в любом регистре. В ответе - только в верхнем!
Дата должна быть в формате: ```<dd/mm/yyyy>```.
Результирующая сумма ввыводится с точностью до двух знаков после запятой.
Данные о курсах можно брать отсюда http://www.cbr.ru/scripts/XML_daily.asp?date_req=25/03/2017

#### bot_id
```
cbr
```

#### Формат команд
```
@<bot_nick> <amount> <currency> [<date>]
```

#### Формат ответа
```
@<user_nick> <amount> <uc_currency> on <data> = <rub_amount> RUB
```

#### Пример
```bash
@vasya > @cbr_bot 10 USD
@cbr_bot > @vasya 10 USD on 29/03/2017 = 585.90 RUB

@vasya > @cbr_bot 10 eur 25/03/2011
@cbr_bot > @vasya 10 EUR on 25/03/2011 = 399.50 RUB
```

#### Рекомендуемые модули
``` 
AnyEvent::HTTP
LWP::UserAgent
XML::Fast
```

<br><br><br>
Трасляция LiveJournal AtomStream
-------------
Бот должен отдавать свежие посты из http://atom.services.livejournal.com/atom-stream.xml. 
При появлении нового поста в стриме, бот должен выводить в чат заголовок и ссылку на пост.
Из текста нужно удалить все переводы строк и схлопнуть все последовательности пробелов и табуляций до одного пробела!

#### bot_id
```
lj_atom
```

#### Формат команд
```
не поддерживаются
```

#### Формат ответа
```
New from LJ AtomStream: <title> <url>
```

#### Пример
```bash
@lj_atom_bot > New from LJ AtomStream: Как Польша снова кинула Францию. http://balalaikin-01.livejournal.com/2008946.html
```

#### Рекомендуемые модули
``` 
AnyEvent::HTTP
LWP::UserAgent
XML::Atom::Stream
AnyEvent::Atom::Stream
```

<br><br><br>
Фильтр мата
-----------
Бот для поиска мата в сообщениях пользователей. Бот обрабатывает весь поток сообщений в чате и, при обнаружении мата,  выводит сообщение с предупреждением. Так же бот должен вести статистику по вынесенным предупреждениям и выводить топ-5 нарушителей по заросу.
Словарь остается на ваше усмотрение, но он должен быть достаточным, что бы пройти тесты ;)

#### bot_id
```
foul_monitor
```

#### Формат команд
```
@<bot_nick> show stat
```

#### Формат ответа
```
Топ 5 нарушителей:
@<user_nick1> - <cnt1>
@<user_nick2> - <cnt2>
@<user_nick3> - <cnt3>
@<user_nick4> - <cnt4>
@<user_nick5> - <cnt5>

@<disturber_nick> - Вам предупреждение за мат!
```

#### Пример
```bash
@vasya > Евлампий - ты мудак!
@foul_monitor_bot > @vasya - Вам предупреждение за мат!
@evlampiy > Сам мудак!
@foul_monitor_bot > @evlampiy - Вам предупреждение за мат!

@petr > @foul_monitor_bot show stat
@foul_monitor_bot > Топ 5:
@vasya - 1
@evlampiy - 1
```

<br><br><br>
Поздравлятор
-----------
Бот для написания поздравлений по запросу пользователя. Поздравления можно брать с сайта http://pozdravok.ru/.
Бот может написать поздравления, как самому пользователю в ответ, так и пользователю, ник которого был указан в команде. 

#### bot_id
```
pozdravok
```

#### Формат команд
```
@<bot_nick> [@<dest_user_nick>]
```

#### Формат ответа
```
@<dest_user_nick>! Тебе поздравления от @<user_nick>!
<text_line1>
...
<text_lineN>

@<user_nick>! Хочу поздравить тебя!
<text_line1>
...
<text_lineN>
```

#### Пример
```bash
@vasya > @pozdravok_bot
@pozdravok_bot > @vasya! Хочу поздравить тебя!
С днем рождения, удачи!
Счастья личного в придачу.
Море смеха и веселья!
И во всех делах везения.

@vasya > @pozdravok_bot @evlampiy
@pozdravok_bot > @evlampiy! Тебе поздравления от @vasya!
Однажды, одна маленькая, но очень гордая птичка не стала никуда лететь, а осталась дома и отлично провела время с семьей. Так выпьем же за крепкий тыл и семейное благополучие, удерживающих нас от безрассудства.
```

#### Рекомендуемые модули
``` 
AnyEvent::HTTP
LWP::UserAgent
HTML::Parser
```

<br><br><br>
Гороскоп
-----------
Бот выводящий по запросу гороскоп для конкрентно знака зодиака.<br>
Гороскоп можно брать тут http://mobs.mail.ru/apps/horo/getHoroscopeBySign?sign_id= <br>
Параметр *sign_id* может принимать значение от 1 до 12 (начиная с Овна). <br>
Бот должен понмать текстовое кириллическое название знака зодиака!<br>
Из текста нужно удалить все переводы строк и схлопнуть все последовательности пробелов и табуляций до одного пробела!

#### bot_id
```
horo
```

#### Формат команд
```
@<bot_nick> <cyr_sign_name>
```

#### Формат ответа
```
@<user_nick> <cyr_sign_name>: <horoscope_text>
```

#### Пример
```bash
@vasya > @horo_bot рак
@horo_bot > @vasya Рак: Неоднозначный день. Он хорошо подходит для того, чтобы отдыхать и строить планы на будущее, а вот с их реализацией лучше не спешить.
```

#### Рекомендуемые модули
``` 
AnyEvent::HTTP
LWP::UserAgent
JSON::XS
```

<br><br><br>
Поле чудес
-----------
Бот играющий с участниками чата в "Поле чудес".<br>
Бот загадывает слово и выводит его в чат, с заменой всех букв на звездочки. Так же бот выводит в чат определение к слову. Слова и определения можно брать как с внешних ресурсов, так и составить свою базу.<br>
После этого бот ждет варианты слов от участников чата. Если в течение одной минуты никто не дал правильный ответ, то бот открывает одну случайную букву в слове.<br>
Если кто-то отгадал слово, то бот поздравляет победителя.<br>
Если никто не отгадал слово за отведенной время, то бот ругается на участников и выводит загаданное слово.<br>
После окончания игры, бот выводит на экран топ 5 самых догадливых, ждет 10 секунд и загадывает новое слово.<br>
Слова должны проверяться без учета регистра.<br>
Бот должен понимать специальную команду: ```!задание```, по которой выводить в чат текущее задание. Если игры в этот момент нет, то игра должна начаться незамедлительно!

#### bot_id
```
yakub
```

#### Формат команд
```
@<bot_nick> <word>
@<bot_nick> !задание
```

#### Формат ответа
```
# Загадываение нового слова
Начинаем новую игру! Загадано слово: <stars_word>
Определение: <description>

# Открываение очередной буквы
Открываем букву: <stars_and_letters_word>

# Реакция на !задание (игра идет)
Загадано слово: <stars_and_letters_word>
Определение: <description>

# Реакция на !задание (игры нет)
Начинаем новую игру! Загадано слово: <stars_word>
Определение: <description>

# Правильный ответ
Ура! @<user_nick> отгадал слово: <word>! Поздравляем победителя!
Топ 5 победителей:
@<user_nick1> - <cnt1>
@<user_nick2> - <cnt2>
@<user_nick3> - <cnt3>
@<user_nick4> - <cnt4>
@<user_nick5> - <cnt5>

# Никто не отгадал слово
Ну как же так?! Это же было слово: <word>!
Топ 5 победителей:
@<user_nick1> - <cnt1>
@<user_nick2> - <cnt2>
@<user_nick3> - <cnt3>
@<user_nick4> - <cnt4>
@<user_nick5> - <cnt5>
```

#### Пример
```bash
@yakub_bot > Начинаем новую игру! Загадано слово: ****
Определение: Зимой и летом одним цветом
@vasya > @yakub_bot огурец
@petr > @yakub_bot снег
@vasya > ёлка
@evlampiy > @yakub_bot ёлка
@yakub_bot > Ура! @evlampiy отгадал слово: ёлка! Поздравляем победителя!
Топ 5 победителей:
@vasya - 10
@evlampiy - 5
@dima - 4
@pert - 1
@nikita - 1

@yakub_bot > Начинаем новую игру! Загадано слово: ***
Определение: Усатый полосатый
@vasya > @yakub_bot огурец
@petr > @yakub_bot дом
@evlampiy > @yakub_bot лес
@yakub_bot > Открываем букву: **т
@dima > @yakub_bot рот
@oleg > @yakub_bot !задание
@yakub_bot > Загадано слово: **т
Определение: Усатый полосатый
@vasya > @yakub_bot мат
@yakub_bot > Открываем букву: к*т
@vasya > @yakub_bot кит
@yakub_bot > Ну как же так?! Это же было слово: кот!
Топ 5 победителей:
@vasya - 10
@evlampiy - 5
@dima - 4
@pert - 1
@nikita - 1
```