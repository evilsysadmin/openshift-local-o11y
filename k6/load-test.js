// torture-test.js
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '3m', target: 50 },  // 50 usuarios!
    { duration: '3m', target: 200 },   // 3 minutos de tortura
    { duration: '30s', target: 0 },
  ],
};

export default function() {
  // Múltiples requests por usuario
  let responses = http.batch([
    ['GET', 'http://httpd-simple-route-my-app-project.apps-crc.testing/'],
    ['GET', 'http://httpd-simple-route-my-app-project.apps-crc.testing/'],
  ]);
  
  // Verificar todas las responses
  responses.forEach((response, index) => {
    check(response, {
      [`request ${index} status is 200`]: (r) => r.status === 200,
    });
  });
  
  // Sin sleep = máximo throughput
}