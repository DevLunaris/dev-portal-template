<?php

use App\Controllers\Api\Health;
use CodeIgniter\Router\RouteCollection;

/**
 * @var RouteCollection $routes
 */

// Das Frontend (Vue) liefert alle Seiten aus. CodeIgniter stellt nur die
// JSON-API unter /api bereit.
$routes->group('api', static function (RouteCollection $routes): void {
    $routes->get('health', [Health::class, 'index']);
});
