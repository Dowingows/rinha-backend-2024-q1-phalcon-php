<?php

use Phalcon\Di\Di;
use Phalcon\Mvc\Micro;
use Phalcon\Http\Response;
use \Phalcon\Db\Adapter\Pdo\Postgresql;

$container = new Di();


class Service
{
  private $connection;

  public function __construct()
  {
    $config = [
      'host'     => getenv('DB_HOST'),
      'username' => getenv('DB_USER'),
      'password' => getenv('DB_PASSWORD'),
      'dbname'   => getenv('DB_NAME'),
      'schema' => 'public',
      "options"    => [\PDO::ATTR_PERSISTENT => 1]
    ];
    

    $this->connection = new Postgresql($config);
  }

  public function getClienteSaldoInfo(int $id): ?array
  {
    $sql = "SELECT saldo, limite from clientes where id = $id";

    $result = $this->connection->query($sql);

    $client = $result->fetch();

    if (!$client) {
      return null;
    }

    return [
      'saldo' => $client['saldo'],
      'limite' => $client['limite'],
    ];
  }

  public function getClienteExtrato(int $id): ?array
  {
    $saldo = $this->getClienteSaldoInfo($id);

    if (!$saldo) {
      return null;
    }
    $saldo['total'] = $saldo['saldo'];
    unset($saldo['saldo']); 
    $saldo['data_extrato'] = (new \DateTime('now'))->format('Y-m-d\TH:i:s.u\Z');
    $extrato = ['saldo' =>$saldo];
    $sql = "SELECT valor, tipo, descricao, TO_CHAR(realizada_em, 'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"') AS realizada_em FROM transacoes where cliente_id = " . $id . " ORDER BY realizada_em DESC LIMIT 10";
    $extrato['ultimas_transacoes'] =  $this->connection->query($sql)->fetchAll(PDO::FETCH_ASSOC);

    return $extrato;
  }

  public function realizarTransacao(int $clientId, int $valor, string $descricao, string $tipo): array
  {
    $result = $this->connection->query("SELECT realizar_transacao({$clientId}, {$valor}, '{$descricao}', '{$tipo}')");
    $info = $result->fetch(PDO::FETCH_ASSOC);

    preg_match('/(-?\d+),\s*(-?\d+)/', $info['realizar_transacao'], $matches);
    list(, $saldo, $limite) = $matches;
    return [(int) $saldo, (int) $limite];
   
  }
}


$app = new Micro();

$app->post(
  '/clientes/{id:[0-9]+}/transacoes',
  function ($id)  use ($app) {

    //cliente não existe deve retornar 404
    $service = $app->getDI()->get('service');
    // $client = $service->getClienteSaldoInfo($id);

    if ($id < 0 || $id > 5) {
      return (new Response())
        ->setStatusCode(404);
    }

    $payload = $app->request->getJsonRawBody();
    // print_r($payload);die;
    // * [id] (na URL) deve ser um número inteiro representando a identificação do cliente.
    // * valor deve um número inteiro positivo que representa centavos (não vamos trabalhar com frações de centavos). Por exemplo, R$ 10 são 1000 centavos.
    // * tipo deve ser apenas c para crédito ou d para débito.
    // * descricao deve ser uma string de 1 a 10 caractéres.
    if ( !is_int($payload->valor) || $payload->valor <= 0 || !in_array($payload->tipo,['c','d']) || empty($payload->descricao) ||strlen($payload->descricao) < 1 || strlen($payload->descricao) > 10)
    {
      return (new Response())->setStatusCode(422);
    }
   

    try {
      // $client['saldo'] = $service->realizarTransacao($id, $payload->valor, $payload->descricao, $payload->tipo);
      list($saldo, $limite) = $service->realizarTransacao($id, $payload->valor, $payload->descricao, $payload->tipo);
    } catch (Exception $e) {
      return (new Response())->setStatusCode(422);
    }

    // $client['saldo'] =  $payload->tipo === 'c' ? $client['saldo'] + $payload->valor : $client['saldo'] - $payload->valor  ;
    // $client = $service->getClienteSaldoInfo($id);
    
    return (new Response())
      ->setStatusCode(200)
      ->setContentType('application/json')
      ->setContent(json_encode(['saldo' => $saldo,'limite'=> $limite], true));
  }
);

$app->get(
  '/clientes/{id:[0-9]+}/extrato',
  function ($id) use ($app) {
    $service = $app->getDI()->get('service');
    $extrato = $service->getClienteExtrato($id);

    if (!$extrato) {
      return (new Response())
        ->setStatusCode(404);
    }

    return (new Response())
      ->setStatusCode(200)
      ->setContentType('application/json')
      ->setContent(json_encode($extrato, true));
  }
);


$app->notFound(function () use ($app) {
  $app->response->setStatusCode(404, "Not Found")->sendHeaders();
});


$app->handle($_SERVER["REQUEST_URI"]);
