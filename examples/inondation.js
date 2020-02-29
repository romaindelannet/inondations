  function adjustAltitude(v) {
      // Here we specify the Z displacement for the water
      globeWater.zDisplacement =  v; //10; //displacement;
      ignElevation.waterLevel = v;

      globeView.notifyChange(globeWater);
      // globeView.notifyChange(ignElevation);
      globeView.notifyChange(true);
  }
