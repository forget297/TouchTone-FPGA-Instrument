from generate_tables import ROOT, tables
if __name__ == '__main__':
    (ROOT/'rtl/audio/sine.hex').write_text(tables()['sine.hex'],encoding='ascii')
