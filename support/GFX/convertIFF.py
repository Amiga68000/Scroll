# http://obligement.free.fr/articles/format_iff_ilbm.php
# http://amigadev.elowar.com/read/ADCD_2.1/Libraries_Manual_guide/node042A.html
# octet = format(15, "02x")  # 15--> 0f
# format(15,"04x")           # 15 --> 000f
# (int("ff",16))             # ff --> 255

# pip install Pillow  --> dans la console

from PIL import Image
import numpy as np


# --- AFFICHAGE
def AffTexte(texte):
    print("")
    print("---------------------------------------")
    print(texte)
    print("---------------------------------------")
    return


def AfficherInfo(Info):
    AffTexte("INFORMATION FICHIER")

    for i in list(Info.keys()):
        print(i, "=", Info[i])

    l = Info["largeur"]
    h = Info["hauteur"]
    n = Info["nbBpl"]
    t = int(l * h * n / 8)
    print(l, "x", h, " x ", n, " bitplanes = ", t, "octets")
    return

def AfficherCoulCopper(Coul):

    AffTexte("Color CopperList")
    reg = int("180",16)
    p=0
    t=""
    for i in list(Coul.keys()):
        c = (Coul[i][0] // 16) * 16 ** 2 + (Coul[i][1] // 16) * 16 + (Coul[i][2] // 16)

        if p==0:
            t = "\tdc.w\t"
        else:
            t = t + ","
        t = t + "$"+format(reg,"04x")+ ",$"+ format(c, "04x")

        if p==3: print(t)

        p = p +1
        if p == 4: p =0
        reg = reg + 2



# --- LECTURE DES DONNEES
def valeur(adresse, longueur):
    # renvoie la valeur numérique de n octets
    # l'octet de poids faibel se trouve au début
    v = 0
    n = 0
    for i in range(adresse, adresse + longueur):
        v = v + data[i] * 256 ** (n)
        n = n + 1
    return v


def ascii(adresse, longueur):
    header = ""
    for i in range(adresse, adresse + longueur):
        header = header + chr(data[i])
    return header


def tailleBloc(adresse):
    v = 0
    n = 3
    for i in range(adresse, adresse + 4):
        v = v + data[i] * 256 ** (n)
        n = n - 1
    return v


def valWord(adresse):
    v = 0
    n = 1
    for i in range(adresse, adresse + 2):
        v = v + data[i] * 256 ** (n)
        n = n - 1
    return v


def valByte(adresse):
    v = data[adresse]
    return v


def LireBMHD(ptr):
    Info = {}
    Info["largeur"] = valWord(ptr)
    Info["hauteur"] = valWord(ptr + 2)
    Info["posx"] = valWord(ptr + 4)
    Info["posy"] = valWord(ptr + 6)
    Info["nbBpl"] = valByte(ptr + 8)
    Info["Masquage"] = valByte(ptr + 9)  # 0 = sans, 1 = masquage, 2 = transparent, 3 = lasso
    Info["Compression"] = valByte(ptr + 10)  # Compression : 0 = sans, 1 = "ByteRun1"
    Info["NumCoulFond"] = valWord(ptr + 12)
    Info["AspectX"] = valByte(ptr + 14)
    Info["AspectY"] = valByte(ptr + 15)
    Info["LargPageSrc"] = valWord(ptr + 16)
    Info["HautPageSrc"] = valWord(ptr + 18)
    return Info


def LireCMAP(ptr, size):
    Coul = {}
    nc = 0
    for i in range(ptr, ptr + size, 3):
        r = valByte(i)
        v = valByte(i + 1)
        b = valByte(i + 2)
        Coul[nc] = (r, v, b)
        nc += 1
    return Coul


def LireBODY(ptr, size):
    # while (not produced the desired number of bytes)
    #         /* get a byte, call it N */
    #         if (N >= 0 && N <= 127)
    #                 /* copy the next N+1 bytes literally */
    #         if (N >= -127 && N <= -1) /* ie 129..255 */
    #                 /* repeat the next byte N+1 times */
    #         if (N == -128)
    #                 /* skip it, presumably it's padding */

    ctrNOP = 0
    Imgarr = []
    p = ptr
    while p < ptr + size - 1:
        if Info["Compression"] == 1:
            # byteRun1 : lire octet n
            # print("p=", p)
            n = valByte(p)

            if n < 128:
                # si n < 128, afficher les n+1 octets
                p += 1
                for i in range(p, p + n + 1):
                    Imgarr.append(valByte(i))
                p = p + n + 1
            elif n > 128:
                # si n > 128, lire octet suivant o, l'afficher (257-n) fois
                p += 1
                o = valByte(p)
                for i in range(257 - n):
                    Imgarr.append(o)
                p = p + 1
            elif n == 128:
                # si n = 128, ne rien faire
                p += 1
                ctrNOP += 1
                print("NOP", ctrNOP)
        else:
            # pas de compression
            p += 1
            for i in range(p, p + n):
                Imgarr.append(valByte(i))
            p = p + n
    # print(Imgarr)
    print("Taille BODY cree = ", len(Imgarr), " octets")
    return Imgarr


# ----------------------------------------------
# --- TRAITEMENT DATA BODY
# ----------------------------------------------

def ConvertBODYToChunky(arr):
    # convertit le BODY entrelacé en Bitplanes continus (chunky)
    # bpl 1 ligne 1                  bpl 1 ligne 1
    # bpl n ligne 1                  bpl 1 ligne m
    # ...                            ...
    # bpl 1 ligne m                  bpl n ligne 1
    # bpl n ligne m                  bpl n ligne m

    AffTexte("Conversion BODY en bitplanes chuncky")

    l = Info["largeur"]
    h = Info["hauteur"]
    n = Info["nbBpl"]
    bplSize = int(l * h * n / 8)
    arrdest = []
    lByte = l // 8

    for numBpl in range(n):
        for y in range(h):
            ptr = ((y * n) + numBpl) * lByte
            # print(ptr)
            d = ptr
            f = ptr + lByte
            # print(arr[d:f])
            arrdest.extend(arr[d:f])
    return arrdest

def ConvertCHUNKYenTILES(arr, Info, largeurTile, hauteurTile):
    # convertit array de largeur l1 en largeur l2

    return


def ExtraireFromBody(Body, Info, x, y, dx, dy, DestInterleaved):
    AffTexte("ExtraireFromBody")

    l = Info["largeur"]
    h = Info["hauteur"]
    n = Info["nbBpl"]
    bplSize = int(l * h / 8)
    arrdest = []
    lByte = l // 8


    offset = int( (x//8)  + y * lByte)
    for numBpl in range(n):
        for y in range(dy):
            if DestInterleaved:
                d = (y + numBpl * dy)
            else:
                d = ((y * n) + numBpl)  # ligne
            d = d * lByte + offset
            f = d + (dx//8)
            arrdest.extend(Body[d:f])
    return arrdest



# ----------------------------------------------
# --- CONSTRUCTION IMAGE POUR AFFICHAGE WINDOWS
# ----------------------------------------------

def ConvertirArray(arraySource, TailleColonne):
    arr = np.reshape(arraySource, (-1, TailleColonne))
    return arr

def ConstruireImage(Body, SourceInterleaved, largeur, hauteur, nbBitplanes, Coul):
    TailleBpl = (largeur * hauteur) // 8
    # On ajoute les données manquantes (BUG à trouver)
    # t = (TailleBpl * nbBitplanes) - len(Body)
    # a = [0]*( t )
    # Body.extend(a)
    # print("Len(body)=",len(Body))

    Img = Image.new('RGB', (largeur, hauteur), (0, 0, 0))
    for y in range(hauteur):
        for x in range(largeur):
            c = 0
            valBit = 2 ** (7 - ((x) % 8))
            for i in range(nbBitplanes):
                if SourceInterleaved:
                    numByte = (((y * nbBitplanes) + i) * largeur) // 8 + x // 8  # ligne entrelacée
                else:
                    numByte = x // 8 + (y * largeur) // 8 + TailleBpl * i
                o = Body[numByte]
                if o & (valBit) != 0:
                    c = c + 2 ** (i)
            # c = code couleur
            cl = Coul[c]
            # print("x=", x, " y=", y, "numByte=", numByte, " valBit=", valBit, "Coul=",cl)

            Img.putpixel((x, y), cl)
    return Img

# ----------------------------------------------
# --- GESTION FICHIER
# ----------------------------------------------
def writeBin(nomFichier, byte_arr):
    AffTexte("Sauvegarde de : " + nomFichier)
    # byte_arr = [120, 3, 255, 0, 100]
    f = open(nomFichier, 'w+b')
    binary_format = bytearray(byte_arr)
    f.write(binary_format)
    f.close()
    return


def lireBin(nomFichier):
    AffTexte("Chargement de : " + nomFichier)
    f = open(nomFichier, "rb")
    data = f.read()
    f.close()
    return data





# ----------------------------------------------
# --- MAIN
# ----------------------------------------------

nom = "Tiles320x256x32c.iff"
Coul = {}
Info = {}
Imgarr = []

data = lireBin(nom)

# Header FORM
ptr = 0
header = ascii(ptr, 4)
print(header)
sizeGlobale = tailleBloc(ptr + 4)
print(format(sizeGlobale, "04x"))

# Header ILBM
ptr += 8
header = ascii(ptr, 4)
print(header)

# Header
ptr += 4

while ptr < sizeGlobale + 8:
    header = ascii(ptr, 4)
    print("-")
    print(header)
    ptr += 4
    size = tailleBloc(ptr)
    print("size = &h", format(size, "04x"), " = ", size)
    ptr += 4
    if header == "BMHD":
        # table des informations image
        Info = LireBMHD(ptr)
        print(Info)
        ptr += size
    elif header == "CMAP":
        # table des couleurs
        Coul = LireCMAP(ptr, size)
        ptr += size
    elif header == "BODY":
        Imgarr = LireBODY(ptr, size)
        ptr += size
    else:
        print("non traité")
        ptr += size



AfficherInfo(Info)

AfficherCoulCopper(Coul)

# array = np.random.randint(255, size=(400, 400),dtype=np.uint8)
arrChunky = ConvertBODYToChunky(Imgarr)

#arrTile = ExtraireFromBody(Imgarr, Info, 32, 0, 64, 64, False)
#image = ConstruireImage(arrTile, False, 64, 64, Info["nbBpl"], Coul)
#image.show()




#image = ConstruireImage(Imgarr, True, Info["largeur"], Info["hauteur"], Info["nbBpl"], Coul)
image = ConstruireImage(arrChunky, False, Info["largeur"], Info["hauteur"], Info["nbBpl"], Coul)
image.show()


# SAUVER
nomDest = nom + ".bin"
writeBin(nomDest, arrChunky)

