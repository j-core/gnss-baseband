configuration gpsif_sim of gpsif is
  for beh
    for all : ram_1rw
      use entity work.ram_1rw(inferred);
    end for;
    for regfile : gpsif_regfile
      use entity work.gpsif_regfile(beh);
      for beh
        for all : bist_RF1
          use configuration work.bist_rf1_inferred;
        end for;
      end for;
    end for;
  end for;
end configuration;

configuration gpsif_top_sim of gpsif_top is
  for arch
    for g : gpsif
      use configuration work.gpsif_sim;
    end for;
  end for;
end configuration;
