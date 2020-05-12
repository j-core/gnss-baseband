configuration gpsif_asic of gpsif is
  for beh
    for regfile : gpsif_regfile
      use entity work.gpsif_regfile(beh);
      for beh
        for all : bist_RF1
          use configuration work.bist_rf1_asic;
        end for;
        for all : bist_RF2
          use configuration work.bist_rf2_asic;
        end for;
      end for;
    end for;
  end for;
end configuration;

configuration gpsif_top_asic of gpsif_top is
  for arch
    for g : gpsif
      use configuration work.gpsif_asic;
    end for;
  end for;
end configuration;
