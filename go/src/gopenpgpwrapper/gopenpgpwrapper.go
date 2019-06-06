package gopenpgpwrapper

import (
    "bytes"
    "io"
    "io/ioutil"

    "github.com/ProtonMail/gopenpgp/crypto"
    "github.com/ProtonMail/gopenpgp/armor"
)

type Key struct {
    kr crypto.KeyRing
}

func (k *Key) GetKeyID() string {
    return k.kr.FirstKeyID
}

func (k *Key) Encrypt(plaintext []byte, armor bool) []byte {
    var b bytes.Buffer
    var w io.WriteCloser
    if armor {
        wr, err := k.kr.EncryptArmored(&b, nil)
        if err != nil {
            return nil
        }
        w = wr
    } else {
        wr, err := k.kr.Encrypt(&b, nil, "", false)
        if err != nil {
            return nil
        }
        
        w = wr
    }

    if _, err := w.Write(plaintext); err != nil {
        return nil
    }

    if err := w.Close(); err != nil {
        return nil
    }

    return b.Bytes()
}

func (k Key) Decrypt(ciphertext []byte, passphrase string) []byte {
    unarmored, err := armor.Unarmor(string(ciphertext))
    if err != nil {
        // Assume ciphertext is already in binary format
        unarmored = ciphertext
    }
    
    err = k.kr.Unlock([]byte(passphrase))
    if err != nil {
        return nil
    }
    
    r, _, err := k.kr.Decrypt(bytes.NewReader(unarmored))
    if err != nil {
        return nil
    }
    
    if b, err := ioutil.ReadAll(r); err != nil {
        return nil
    } else {
        return b
    }
}

func ReadKey(data []byte) *Key {
    kr, err := crypto.ReadArmoredKeyRing(bytes.NewReader(data))
    if err != nil {
        // Assume keyring is in binary form
        kr, err = crypto.ReadKeyRing(bytes.NewReader(data))
        if err != nil {
            return nil
        }
    }
    
    return &Key{kr: *kr}
}
