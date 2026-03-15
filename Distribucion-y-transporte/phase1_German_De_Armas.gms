*$Title Fase 1: Localizacion Optima de CEDI en China - Versión Corregida
* German Eduardo De Armas Castaño - T00068765
* Carrera: Ingenieria Industrial - UTB
Sets
    i   Ciudades de origen (producción) / Xiamen, Fuzhoun, Ningbo, HongKong, Shanghai /
    k   Posibles ubicaciones de CEDI   / Xiamen, Fuzhoun, Ningbo, HongKong, Shanghai /;

Alias(i, j);

Parameters
    O(i)  "Oferta minima de cada ciudad (unidades)"
    / Xiamen    1720
      Fuzhoun   1400
      Ningbo    3200
      HongKong  2200
      Shanghai  1260 /

    G(k)  "Costo unitario de gestion y almacenamiento (US$ por unidad)"
    / Xiamen    0.116
      Fuzhoun   0.124
      Ningbo    0.095
      HongKong  0.104
      Shanghai  0.083 /

    F(k)  "Costo fijo ANUAL de mantenimiento del CEDI (US$)"
    / Xiamen    34500
      Fuzhoun   38640
      Ningbo    34296
      HongKong  34224
      Shanghai  36156 /;

* --- Matriz de costos unitarios de transporte desde i hasta k ---
Table C(i,k) "Costo unitario de transporte (US$)"
                Xiamen  Fuzhoun  Ningbo  HongKong  Shanghai
    Xiamen      0.01    0.18     0.34    0.27      0.38
    Fuzhoun     0.18    0.00     0.25    0.33      0.35
    Ningbo      0.34    0.25     0.00    0.41      0.21
    HongKong    0.27    0.33     0.41    0.01      0.44
    Shanghai    0.38    0.35     0.21    0.44      0.01 ;

Scalar n "Maximo numero de CEDIs a abrir" /1/;

Variables
    x(i,k)  "Cantidad de unidades enviadas desde i hasta el CEDI k"
    y(k)    "Variable binaria: 1 si se abre el CEDI en k, 0 si no"
    z       "Costo total (Funcion objetivo)" ;

Positive Variable x;
Binary Variable y;

Equations
    Objetivo         "Minimizar Costo Fijo + Transporte + Almacenamiento"
    RestriccionCEDI  "Limita el numero de CEDIs a abrir"
    SatisfacerOferta "Asegura que se despache toda la produccion de i"
    Vinculo(i,k)     "Solo se puede enviar a un CEDI si este esta abierto" ;

* La función objetivo suma: 
* 1. Costos fijos de apertura.
* 2. Costos de transporte multiplicado por flujo.
* 3. Costos de almacenamiento en el CEDI k por las unidades recibidas.
Objetivo..          z =e= sum(k, F(k)*y(k)) + sum((i,k), (C(i,k) + G(k)) * x(i,k));

RestriccionCEDI..   sum(k, y(k)) =e= n;

SatisfacerOferta(i).. sum(k, x(i,k)) =g= O(i);

* M es un número suficientemente grande (Big-M) para activar el flujo
Vinculo(i,k)..      x(i,k) =l= 1000000 * y(k);

Model Fase1China /all/;

* Se usa MIP porque y(k) es binaria
Solve Fase1China minimizing z using mip;

Display y.l, x.l, z.l;