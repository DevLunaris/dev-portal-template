<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use CodeIgniter\API\ResponseTrait;
use CodeIgniter\HTTP\ResponseInterface;
use Config\Database;
use Throwable;

/**
 * GET /api/health
 *
 * Prüft, ob die API läuft und die Datenbank erreichbar ist.
 */
class Health extends BaseController
{
    use ResponseTrait;

    public function index(): ResponseInterface
    {
        $database = ['connected' => false];

        try {
            $db = Database::connect();
            $db->initialize();
            $db->query('SELECT 1');

            $database = [
                'connected' => true,
                'name'      => $db->getDatabase(),
                'version'   => $db->getVersion(),
            ];
        } catch (Throwable $e) {
            // Fehlerdetails nur außerhalb von production herausgeben
            if (ENVIRONMENT !== 'production') {
                $database['error'] = $e->getMessage();
            }
        }

        return $this->respond([
            'status'      => $database['connected'] ? 'ok' : 'error',
            'environment' => ENVIRONMENT,
            'database'    => $database,
            'time'        => date(DATE_ATOM),
        ], $database['connected'] ? 200 : 503);
    }
}
