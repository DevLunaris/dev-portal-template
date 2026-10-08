<?php

// phpMyAdmin läuft im Dev-Portal unter /pma/. Die Adresse wird aus den
// Proxy-Headern gebildet, damit es per Pangolin (HTTPS) und im LAN klappt.
$proto = $_SERVER['HTTP_X_FORWARDED_PROTO'] ?? 'http';
$host  = $_SERVER['HTTP_X_FORWARDED_HOST'] ?? ($_SERVER['HTTP_HOST'] ?? 'localhost');
$cfg['PmaAbsoluteUri'] = $proto . '://' . $host . '/pma/';

// Einbetten ins Dev-Portal (gleicher Origin) erlauben
$cfg['AllowThirdPartyFraming'] = 'sameorigin';
