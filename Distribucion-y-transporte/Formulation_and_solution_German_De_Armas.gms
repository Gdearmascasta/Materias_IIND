$Title Modelo LARP_Linearized
* German Eduardo De Armas Castaño - T00068765
* Carrera: Ingenieria Industrial - UTB


Sets
    c       "Campos de residuos (Clusteres)"       /C1*C7/
    s       "Sitios potenciales de almacenamiento" /S1*S6/
    n       "Nodos totales de la red (F3 + S1 a S6)" /F3, S1*S6/ ;

Alias (n, m);

Sets
    Plant(n)   /F3/
    Storage(n) /S1*S6/;

Parameters
    SetupCost(n)    "Costo fijo de apertura (millones VND)"
    WasteVolume(c)  "Cantidad de residuos en el cluster c (toneladas)"
    Capacity_S(n)   "Capacidad de almacenamiento (toneladas)"
    FleetSize       "Numero maximo de vehiculos disponibles" /3/
    VehCap          "Capacidad fisica del vehiculo (toneladas)" /10/ ;

* --- DATOS REALES EXTRAIDOS DE LAS TABLAS DEL PAPER ---

* Tabla 4: Costos y Capacidades
SetupCost(Storage) = 100;

Capacity_S('S1') = 8; Capacity_S('S2') = 8; Capacity_S('S3') = 8;
Capacity_S('S4') = 6; Capacity_S('S5') = 6; Capacity_S('S6') = 6;

* Tabla 3: Demanda de los clusteres
WasteVolume('C1') = 3; WasteVolume('C2') = 4; WasteVolume('C3') = 3; 
WasteVolume('C4') = 4; WasteVolume('C5') = 3; WasteVolume('C6') = 4; 
WasteVolume('C7') = 3;

* Tabla 5: Matriz de distancias 
Table Dist_Field(c,n) "Distancia del campo al almacenamiento en km"
        S1    S2    S3    S4    S5    S6
    C1  3.8   5.7   16.8  1.5   5.7   13.0
    C2  4.4   5.0   16.6  9.2   6.0   12.8
    C3  6.2   6.9   19.5  2.5   3.4   10.3
    C4  5.2   4.5   17.0  0.3   6.0   12.5
    C5  2.6   7.0   17.0  3.0   5.7   13.9
    C6  2.0   7.5   16.7  3.7   6.2   14.5
    C7  3.5   6.2   17.0  7.0   5.4   13.2 ;

* Tabla 6: Matriz de distancias Red Logistica (Dist_Net para Escenario 3)
Table Dist_Net(n,m) "Distancia entre nodos de la red en km"
        F3    S1    S2    S3    S4    S5    S6
    F3  0     4.0   12.0  15.0  8.5   11.0  17.5
    S1  4.0   0     8.0   19.0  5.0   9.5   16.5
    S2  12.0  8.0   0     17.0  4.5   9.0   14.5
    S3  15.0  19.0  17.0  0     21.0  28.0  33.5
    S4  8.5   5.0   4.5   21.0  0     5.0   15.0
    S5  11.0  9.5   9.0   28.0  5.0   0     10.0
    S6  17.5  16.5  14.5  33.5  15.0  10.0  0    ;

Variables
    Total_Cost      "Valor de la funcion objetivo (Millones VND)"
    Open(n)         "Binaria: 1 si la instalacion n se abre"
    Assign(c,n)     "Continua: proporcion de residuos del campo c al almacen n"
    Route(n,m)      "Binaria: 1 si el vehiculo viaja del nodo n al m"
    W(n,m)          "Binaria: Auxiliar linealizacion (Open(n) * Route(n,m))"
    W_prime(n,m)    "Binaria: Auxiliar linealizacion (Open(m) * Route(n,m))"
    Load(n)         "Continua: Carga acumulada para eliminacion de sub-tours (MTZ)" ;

Binary Variables Open, Route, W, W_prime;
Positive Variables Assign, Load;

Equations
    Obj_Function    "Minimizar costos totales de inversion y operacion"
    Cov_Field       "Cada campo debe ser asignado al 100%"
    Cap_Storage     "Respetar capacidad del almacen y su estado de apertura"
    Flow_Out        "Salida de vehiculos desde la planta"
    Flow_In         "Retorno de vehiculos a la planta"
    SubTour_MTZ_1   "Eliminacion de sub-tours (Lazo de carga)"
    SubTour_MTZ_2   "Limite inferior de la carga acumulada"
    Lin_W1, Lin_W2, Lin_W3, Lin_W4          "Linealizacion de W"
    Lin_Wp1, Lin_Wp2, Lin_Wp3, Lin_Wp4      "Linealizacion de W_prime" ;

* Costo Total = Apertura + Recoleccion  + Transporte (Rutas)
Obj_Function.. 
    Total_Cost =e= sum(Storage, SetupCost(Storage)*Open(Storage)) 
                 + sum((c, Storage), Dist_Field(c, Storage)*WasteVolume(c)*Assign(c, Storage)) 
                 + sum((n,m)$(not sameas(n,m)), Dist_Net(n,m)*Route(n,m));

Cov_Field(c).. 
    sum(Storage, Assign(c, Storage)) =e= 1;

Cap_Storage(Storage).. 
    sum(c, WasteVolume(c)*Assign(c, Storage)) =l= Capacity_S(Storage)*Open(Storage);

* Flujo de flota (=l= para no forzar uso innecesario de camiones)
Flow_Out.. sum(m$Storage(m), Route('F3',m)) =l= FleetSize;
Flow_In..  sum(n$Storage(n), Route(n,'F3')) =l= FleetSize;

* Eliminacion de Sub-tours logic MTZ
SubTour_MTZ_1(n,m)$(Storage(n) and Storage(m) and (not sameas(n,m))).. 
    Load(n) - Load(m) + VehCap*Route(n,m) =l= VehCap - (1/FleetSize)*sum(c, WasteVolume(c)*Assign(c,m));

SubTour_MTZ_2(n)$Storage(n).. 
    (1/FleetSize)*sum(c, WasteVolume(c)*Assign(c,n)) =l= Load(n);

* Linealizacion W(n,m) equivalente a Open(n)*Route(n,m)
Lin_W1(m)$Storage(m)..           sum(n$(not sameas(n,m)), W(n,m)) =e= Open(m);
Lin_W2(n,m)$(not sameas(n,m))..  W(n,m) =l= Open(n);
Lin_W3(n,m)$(not sameas(n,m))..  W(n,m) =l= Route(n,m);
Lin_W4(n,m)$(not sameas(n,m))..  W(n,m) =g= Open(n) + Route(n,m) - 1;

* Linealizacion W_prime(n,m) equivalente a Open(m)*Route(n,m)
Lin_Wp1(n)$Storage(n)..          sum(m$(not sameas(n,m)), W_prime(n,m)) =e= Open(n);
Lin_Wp2(n,m)$(not sameas(n,m)).. W_prime(n,m) =l= Open(m);
Lin_Wp3(n,m)$(not sameas(n,m)).. W_prime(n,m) =l= Route(n,m);
Lin_Wp4(n,m)$(not sameas(n,m)).. W_prime(n,m) =g= Open(m) + Route(n,m) - 1;

* --- COMANDOS ESTRUCTURALES Y SOLUCION ---

* 1. La Planta F3 es infraestructura fija
Open.fx('F3') = 1;

* 2. Acotar el volumen del vehiculo (60)
Load.up(n) = VehCap;

Model LARP_Real /all/;
Solve LARP_Real using mip minimizing Total_Cost;

Display Total_Cost.l, Open.l, Route.l, Assign.l;