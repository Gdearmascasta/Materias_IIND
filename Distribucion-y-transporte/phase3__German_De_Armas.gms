$Title Modelo Fase 3: Optimización de Red Global Multi-Periodo
* German Eduardo De Armas Castaño - T00068765
* Carrera: Ingenieria Industrial - UTB

Sets
    i   Plantas_Origen / Rumania, Xiamen, Fuzhoun, Ningbo, Hong_Kong, Shanghai, Bombay, Bangkok, Brasil, Colombia /
    k   Nodos_Logisticos / Alemania, Ningbo, Colombia, Brasil, Panama, Hong_Kong /
    a(k) Hubs_Primarios / Alemania, Ningbo, Colombia, Brasil /
    j   Zonas_Mercado / Zona1, Zona2, Zona3, Zona4, Zona5 /
    t   Horizonte_Temporal / 2012, 2013, 2014, 2015, 2016 / ;

Alias(k, k_sub);

* ========================================================
* PARÁMETROS Y TABLAS 
* ========================================================

Table p_Cia(i,*) Costo origen a CEDI (Tramo 1)
                Alemania  Ningbo  Colombia  Brasil
    Rumania     0.183     100     1.958     1.712
    Xiamen      2.017     0.343   1.632     2.451
    Fuzhoun     2.123     0.245   1.655     2.412
    Ningbo      1.987     0.004   1.641     2.385
    Hong_Kong   1.995     0.412   1.561     2.587
    Shanghai    2.034     0.206   1.629     2.121
    Bombay      2.196     1.188   2.317     2.689
    Bangkok     2.009     0.996   2.239     2.966
    Brasil      100       100     0.914     0.012
    Colombia    100       100     0.016     0.914 ;

Table p_Cak(k,*) Costo entre CEDIs (Inter-Hub)
                Alemania  Panama  Colombia  Brasil
    Alemania    0         2.010   2.015     1.875
    Ningbo      0.987     1.012   1.018     1.175
    Colombia    2.015     0.471   0         0.518
    Brasil      1.875     0.697   0.518     0     ;

Table p_Ckj(k,*) Costo CEDI a Zona (Ultima Milla)
                Zona1   Zona2   Zona3   Zona4   Zona5
    Alemania    0.305   2.455   2.213   2.138   2.104
    Ningbo      1.075   0.813   1.107   1.174   1.308
    Hong_Kong   1.051   0.706   1.145   1.174   1.332
    Colombia    2.193   2.487   0.588   0.216   0.609
    Brasil      2.006   2.455   0.722   0.612   0.381
    Panama      1.924   2.214   0.319   0.487   0.615 ;

Parameters
    p_CP(i)     Costo produccion origen
    p_D(j,t)    Demanda zona
    p_S(i)      Oferta minima
    p_MaxCap(i) Oferta maxima
    p_G(k)      Costo almacenamiento
    p_U(k)      Capacidad max CEDI
    p_V(k)      Capacidad min CEDI
    p_F(k)      Costo fijo CEDI ;

p_CP(i) = 3.2;
p_D(j,t)= 1500;
p_S(i)  = 100;
p_MaxCap(i) = 8000;
p_G(k)  = 0.20;
p_F(k)  = 4500;
p_U(k)  = 2500;
p_V(k)  = 500;

* ========================================================
* VARIABLES (RENOMBRADAS)
* ========================================================
Variables
    v_FlujoProd(i,k,t)  "Cantidad enviada de Origen i a Hub k"
    v_Transfer(k,k_sub,t) "Envio entre Hubs k y k_sub"
    v_Despacho(k,j,t)   "Envio de Hub k a Zona j"
    v_Stock(k,t)        "Inventario remanente al final del periodo"
    v_Open(k)           "Estado binario del CEDI k (1=Abierto)"
    v_Active(i,t)       "Estado binario del Origen i (1=Activo)"
    v_CostoTotal        "Costo total de operacion de la red" ;

Positive Variables v_FlujoProd, v_Transfer, v_Despacho, v_Stock;
Binary Variables v_Open, v_Active;

* ========================================================
* ECUACIONES (LÓGICA INTACTA)
* ========================================================
Equations
    Eq_Objetivo, Eq_CapMax, Eq_CapMin, Eq_Demanda, Eq_CapaMaxHub, Eq_CapaMinHub, Eq_BalanceInv ;

Eq_Objetivo.. 
    v_CostoTotal =e= sum((i,k,t)$a(k), (p_CP(i) + p_Cia(i,k)) * v_FlujoProd(i,k,t))
                    + sum((k,k_sub,t)$(a(k) and not sameas(k,k_sub)), p_Cak(k,k_sub) * v_Transfer(k,k_sub,t))
                    + sum((k,j,t), p_Ckj(k,j) * v_Despacho(k,j,t))
                    + sum(k, p_F(k) * v_Open(k))
                    + sum((k,t), p_G(k) * v_Stock(k,t));

Eq_CapMax(i,t)..   sum(k$a(k), v_FlujoProd(i,k,t)) =l= p_MaxCap(i) * v_Active(i,t);
Eq_CapMin(i,t)..   sum(k$a(k), v_FlujoProd(i,k,t)) =g= p_S(i) * v_Active(i,t);
Eq_Demanda(j,t)..  sum(k, v_Despacho(k,j,t)) =e= p_D(j,t);

Eq_CapaMaxHub(k,t).. 
    v_Stock(k, t-1) + sum(i$a(k), v_FlujoProd(i,k,t)) + sum(k_sub$(a(k_sub) and not sameas(k_sub,k)), v_Transfer(k_sub,k,t)) =l= p_U(k) * v_Open(k);

Eq_CapaMinHub(k,t).. 
    v_Stock(k, t-1) + sum(i$a(k), v_FlujoProd(i,k,t)) + sum(k_sub$(a(k_sub) and not sameas(k_sub,k)), v_Transfer(k_sub,k,t)) =g= p_V(k) * v_Open(k);

Eq_BalanceInv(k,t)..
    v_Stock(k,t) =e= v_Stock(k, t-1) 
                    + sum(i$a(k), v_FlujoProd(i,k,t)) 
                    + sum(k_sub$(a(k_sub) and not sameas(k_sub,k)), v_Transfer(k_sub,k,t)) 
                    - sum(j, v_Despacho(k,j,t)) 
                    - sum(k_sub$(a(k) and not sameas(k,k_sub)), v_Transfer(k,k_sub,t));

Model Fase3_Global_Definitiva /all/;

* ========================================================
* JERARQUÍA DE DECISIONES ANTERIORES
* ========================================================
v_Open.fx('Ningbo') = 1;
v_Active.fx('Rumania', t) = 1;

* ========================================================
* SOLUCIÓN
* ========================================================
Solve Fase3_Global_Definitiva using mip minimizing v_CostoTotal;

Display v_Open.l, v_FlujoProd.l, v_Transfer.l, v_Stock.l, v_CostoTotal.l;
