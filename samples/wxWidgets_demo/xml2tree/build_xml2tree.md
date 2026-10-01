Compile with wxWidgets only:

cx run --cpp --opt -o xml2tree \
  --cflags="$(wx-config-3.3 --cxxflags) $(wx-config-3.3 --libs)"