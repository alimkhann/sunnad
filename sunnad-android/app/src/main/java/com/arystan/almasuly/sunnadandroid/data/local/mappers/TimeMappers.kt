package com.arystan.almasuly.sunnadandroid.data.local.mappers

import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneOffset

fun Instant.toEpochMillisSafe(): Long = toEpochMilli()

fun Long.toInstantSafe(): Instant = Instant.ofEpochMilli(this)

fun LocalDateTime.toEpochMillisUtc(): Long = toInstant(ZoneOffset.UTC).toEpochMilli()

fun Long.toLocalDateTimeUtc(): LocalDateTime = Instant.ofEpochMilli(this).atOffset(ZoneOffset.UTC).toLocalDateTime()

fun LocalDate.toIsoString(): String = toString()

fun String.toLocalDateSafe(): LocalDate = LocalDate.parse(this)
