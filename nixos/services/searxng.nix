{ pkgs, ... }:
{
  services.searx = {
    enable = true;
    package = pkgs.searxng;

    configureUwsgi = true;
    uwsgiConfig = {
      disable-logging = true;
      workers = 8;
      threads = 4;
      http = "127.0.0.1:9000";
    };

    settings = {
      server = {
        port = 9000;
        bind_address = "127.0.0.1";
        secret_key = "9eb250a7fabc56fd385e058b2375ef4e42f42aa1cba587aa6a9821430fc59802";
        base_url = "http://localhost/";
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."http://localhost/" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:9000";
        proxyWebsockets = true;
      };
    };
  };

  # Restore settings URL:
  # http://localhost/preferences?preferences=eJx1WMuu47gR_ZrxRogxSQcJsvAqQLYJMLMXKLIsVYti6fJhW_frU9SzaLkX1908JItkPU9JqwgteYRwa8GBV_ZilWuTauGmUqSLJa0s3MBd8lDTMFqIcDNJ9_mvpctdPVCTqz0Esg_wtwsOvL0ePb2m23-UDXAZIHZkbv_77x9_XoK6QwDldXf7_RI7GOAWMIu9sIRkY6hZmINnHVWzbjeEh3hSPLySby_LtjrEya631eAi-FpZbN3A_1_3K_NQToOp13MX9CuBn2p0dcTIAhZwWZGvoBfVTLzJgo63P32CS0exhyncHjhckrf1nfygYkTX3kYPMU4Xg0E1ls8C16Jjvf74x--r0HpV8W9_-_cOVg80QKGul3956l-taus6kEZlqwEMKgaVvicnFrEOGqgCW6Sv61nfb-gi9_OOSiWDPDekgDpP2ZFvWll06VWNSvdZHIuNec45Fap8U3xAXd_RLie5oOpspXkw9tWA3pMXC0Y2TcW_-Uhf7FTsLUZt8kMv9dIoNOkEVMsLxUsXuFd43wQ1aDH_iSc3bJZCFkbdpQjFktiwG0PcpIxNsSMabNvj8rM5rlrrq5FStNLdVFF4V572FIKHO5tTI7AHLtjTPJD9W5wzwfg2PD85g1nhu9oNwDc7-25GAyGqiLyAOKx8RkxbGbijw4jkgjyCbzNpS2fPBL4fGiFjj_TzlcTcyY3FXHnrA3-CyoccZy1OM6iRl_Nvvs1AP3HMWj9WcbTBBPLOf32JS92Np_yAzWb8fBM7FQfONHKZBw4Husen8lAZ9BzjOdoXy909uh6VlhumSailBfzuOGMciCYDDfh2ldBiBHYVGrYxkfGgjNjBUMvvHa2acqSE485yZiD2FqlZTjjgc3LIaVeao2PvA79oez6zg9fuibwpXHPULzPzAesAbTVSiLuJcDDNcUsc2uTFKeiUuAwbx7N7TXLBF04yDH9i6OiQx2HqlZ-qbL6A4tHbBN0rfljLCV8-zlITIlz99jYuKUqPym1DzMHG5qwsu_SO0neH0lOG59BYCbisRP4T93XjZjM3KXXcj8wUQIY9jeC4OL5keGdsfYg8JsN8YxB6yJCHkYQGlvSBYctGI75Uwy5wCrxt4hR1XITOIb2DHwTtU5uoT9uKAB5Tw9nvsV0xNRZ1ZWhQ6Bb5R7XYj_lKyhd5fgbO1_l6KhflOg_GYDyVQ49tFyujqFhLMXLN55tEAhFmyyOGKWAssgbX9XsX4imMArVU1KAZOF92gU8mWOAnaM45R9bDoFMI13FiIrR5p1bGTDlFDGkNocXof-nIwgln71eDyILUTxSJQ6vPQbC5UMyXC3x28QKJrjeKRZBPypnsyKIGzciHMrTgc9E5as-kOKPI7U9spnLcY0PUh3fwK1FplgwGSl6f0RH0nAp_AR9RmGHmimHWXrn6QVNmpxIle_dqYBbUqaKq_Pjxz9ehWZMMOOlV3y7bQ-QW-gnQn5GzDle8CKs5zY9oKR5nOPXI5VFkqwyc5S1wIW6BTs7pUzO1MGxJdATwMTUyqc0hxuf3maM8oRFTk9JT6SL6Q27yiVOslGjZFIFTm8Se9MKeHCeSKkyO3JRr86Fa6N-es0DnEJzhcwhGr3SRR8KjzblWbE2v50wPd-DBrGGmwKtusrMMTJ2kGM7sRwVanJQJ5abMvr22JHJjABe0Z-7Fncb6ugtXjKI7mPPrwrzzgVvhwRezSQEoH1GSEeVf-JAe33BYajWMR0jm3StzkhTYtR_YdEYLfc_ISa-5ZOWwkqldd3DvKRecnQgl7zO9lOeyUpBTOz9D0kd4vOdeQ5nCVF1qhBWMisUjDgpZENc4DcS11wlPunNt6iV54eWYwqGkNheMjRQxZbOqOQbHLdqVLh2nrQztpMoVL5S5Yid1rjjnZbLKS2t2ihlE_tnoWmrZXdr7HETvSJX1EyCGD1Nz3G0TPStDBcm4YBimais0Sw4tC-2yIgXwv5rLzPFXc1kyK_jDNN_vUdjUJo1G-tWguHE05H5x-D7dqdBxefuwwhzc8MWtTjKH2QfF7B427ZK1nP63QSZ13A0cSi3JXZ5bSI9am6pynnMPQOTuZWthRpPz67Fo7Lhsu30W8xcLCDIuRsxsnfmdYIbE0R2485mr9ObefA9-bSF8GreUMXOp0hEX6DPr-lArlEGqGu4Hg2wzPXAL7WVqHlFtpFOwoMQJqdQ6t6e6J04gd0vPo_9PTXIxbTkzcUORwm6bAGwrzn2foiTkfDK-VfMdfCsgO_yBx1k03Pv5xVU3lScXuP8KXcF9mOWUcidKbwV0R_a-XKHl1JS9RSx74FB8n8mJrpDMQN4yNxKbwfOiHFTsd9fTO-TkyZhy8u3zj5yaHy84D-r4Ta5Q8MC1euBOueIi64JlTzUlm_LGYS-JKsXcg2eTvoXoM0Z_RUGqOOs9isNm4PzUBT49coHLQhb_Lr_fsIq5FeYucamtS03eP9mNNnHmDDdS9fLJ8cnVG-Y3-JoLne5_y_3v_EEF_uCG09q9oG97cz5aB3mjn3vyOn8r9Ky2x1IhldWJNUd-9jNucLgM8lRc6Y-913wK5f3sJXW2wIX5PieX2_8B_LEryA== 
}
