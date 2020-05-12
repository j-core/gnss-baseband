configuration gpsif_fpga of gpsif is
  for beh
    for regfile : gpsif_regfile
      use entity work.gpsif_regfile(beh);
      for beh
        for all : bist_RF1
          use configuration work.bist_rf1_inferred;
        end for;
        for all : bist_RF2
          use configuration work.bist_rf2_inferred;
        end for;
      end for;
    end for;
  end for;
end configuration;

configuration gpsif_top_fpga of gpsif_top is
  for arch
    for g : gpsif
      use configuration work.gpsif_fpga;
    end for;
  end for;
end configuration;
