* Phase II: Selección de proveedor y localización óptima de un CEDI para Europa
* Modelo simplificado: elegir 1 CEPRO (origen) y 1 CEDI (ubicación) que abastezcan todas las demandas
$Title Fase 2: Red de Distribución Europea - Versión Binaria (Estilo Montoya)
* German Eduardo De Armas Castaño - T00068765
* Carrera: Ingenieria Industrial - UTB

Sets
    i   Proveedores (CEPRO) / Polonia, Rumania /
    k   Posibles CEDIs      / Polonia, Rumania, Espana, Francia, Reino_Unido, Alemania /
    j   Puntos de Consumo   / Espana, Francia, Reino_Unido, Alemania /;

Parameters
    D(j)   "Demanda anual por país"
    / Espana 1250, Francia 1230, Reino_Unido 1180, Alemania 1140 /

    CP(i)  "Costo unitario de produccion"
    / Polonia 2.50, Rumania 2.48 /

    G(k)   "Costo unitario de gestion en CEDI"
    / Polonia 0.18, Rumania 0.21, Espana 0.20, Alemania 0.18, Reino_Unido 0.23, Francia 0.23 /

    F(k)   "Costo fijo ANUAL del CEDI"
    / Polonia 1950, Rumania 2100, Espana 2050, Alemania 1890, Reino_Unido 2130, Francia 2120 /;

* --- Inferencia de Costos de Transporte (Simplificado como Sebastian) ---
* Se asume un costo base y se reduce si el CEDI y el Cliente coinciden.
Parameter CostoTrans(i,k,j) "Costo de transporte consolidado por ruta";
CostoTrans(i,k,j) = 1.55; 
CostoTrans(i,k,j)$(sameas(k,j)) = 0.55;

Variables
    v_X(i,k,j)  "Binaria: 1 si el cliente j es atendido por la planta i via CEDI k"
    v_Y(i)      "Binaria: 1 si la planta i esta activa"
    v_Z(i,k)    "Binaria: 1 si existe conexion entre planta i y CEDI k"
    z           "Costo total" ;

Binary Variables v_X, v_Y, v_Z;

Equations
    Objetivo         "Minimizar Costos Totales (Produccion + Variable + Fijo)"
    SatisfacerDem(j) "Cada cliente j debe tener asignada exactamente UNA ruta"
    Eq_Vinculo_1     "Una ruta X solo existe si hay conexion Z"
    Eq_Vinculo_2     "Una conexion Z solo existe si la planta Y esta activa"
    SoloUnaPlanta    "Restriccion de Sebastian: Solo una planta activa";

* El costo variable se aplica a TODA la demanda del cliente j si se elige esa ruta.
Objetivo..  z =e= sum((i,k,j), (CP(i) + G(k) + CostoTrans(i,k,j)) * D(j) * v_X(i,k,j)) 
                  + sum(k, F(k) * sum(i, v_Z(i,k)));

* Cada mercado j debe ser cubierto por exactamente una combinacion i-k.
SatisfacerDem(j).. sum((i,k), v_X(i,k,j)) =e= 1;

* Jerarquia de activacion (Lógica del PDF de Montoya)[cite: 8, 10].
Eq_Vinculo_1(i,k,j).. v_Z(i,k) =g= v_X(i,k,j);
Eq_Vinculo_2(i,k)..   v_Y(i)   =g= v_Z(i,k);

* Siguiendo la restriccion corregida por Sebastian[cite: 8].
SoloUnaPlanta..       sum(i, v_Y(i)) =e= 1;

Model Fase2_Binario /all/;
Solve Fase2_Binario minimizing z using mip;

Display v_X.l, v_Y.l, v_Z.l, z.l;