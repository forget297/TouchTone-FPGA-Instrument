from generate_tables import ROOT, tables
if __name__ == '__main__':
    (ROOT/'rtl/audio/fcw.hex').write_text(tables()['fcw.hex'],encoding='ascii')
