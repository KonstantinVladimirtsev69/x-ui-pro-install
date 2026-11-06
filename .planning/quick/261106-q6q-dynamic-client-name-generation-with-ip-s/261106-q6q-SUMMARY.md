---
id: 261106-q6q
slug: dynamic-client-name-generation-with-ip-s
title: Динамическая генерация имени первого клиента с суффиксом IP
status: complete
date: 2026-11-06
---

# Summary: Динамическая генерация имени первого клиента с суффиксом IP

## Overview
Устранен хардкод имени `first` для первого клиента VPN. Реализована схема формирования имени:
- Дефолт при пустом вводе: `${HOSTNAME_SHORT}-${IP_OCTET}` (например, `play2go-236`).
- Ручной ввод: принудительное добавление суффикса `-${IP_OCTET}` без дублирования.
- Санитизация: исключение недопустимых для URL символов.

## Changes
- `x-ui-pro.sh`:
  - Добавлена функция `resolve_client_name()` с санитизацией и автодобавлением суффикса `-${IP_LAST}`.
  - Добавлен параметр `-client_name` в цикл разбора аргументов.
  - Подставлен `$client_name` в SQLite запросы (`client_traffics`, `inbounds` settings: `email`, `subId`), пути подписки и вывод деталей.
- `install.sh`:
  - Добавлено интерактивное приглашение ввода имени клиента с показом вычисленного дефолта `[${DEFAULT_CLIENT}]`.
  - Передача вычисленного `-client_name` в `x-ui-pro.sh`.
- `tests/test_client_name.sh`:
  - Набор тестов логики генерации и санитизации (пройден 100%).
- `tests/test_install_wrapper.sh`:
  - Тест логики обертки `install.sh` (пройден 100%).

## Verification
- `bash -n install.sh` — синтаксис корректен.
- `bash -n x-ui-pro.sh` — синтаксис корректен.
- `tests/test_client_name.sh` — 7/7 тестов пройдены успешно.
- `tests/test_install_wrapper.sh` — пройден успешно.
