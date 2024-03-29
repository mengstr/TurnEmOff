#include <avr/pgmspace.h>
#include <TimerOne.h>

//
// Maze generating code from Lars Schumann
// http://make.larsi.org/electronics/ATmegaX8/Peggy2LE/
//
//


/*
            D14 A0   PC0 TLed Anode 1,11,21
 D15 A1   PC1 TLed Anode 2,12,22
 D16 A2   PC2 TLed Anode 3,13,23
 D17 A3   PC3 TLed Anode 4,14,24
 D18 A4   PC4 TLed Anode 5,15,25
 D19 A5   PC5 TLed Anode 6,16,26
 
 D2       PD2 TLed Anode 7,17,27
 D3       PD3 TLed Anode 8,18,28
 D4       PD4 TLed Anode 9,19
 D5       PD5 TLed Anode 10,20
 D6       PD6 Led Anode 1,3,5  
 D7       PD7 Led Anode 2,4,6
 
 D8       PB0 Led Cathode 21-28
 D9       PB1 Led Cathode 11-20
 D10      PB2 Led Cathode  1-10
 D11      PB3 Touch In  1-10
 D12      PB4 Touch In 11-20
 D13      PB5 Touch In 21-28
 */


/*
KEY LAYOUT

            26 27 28

      1  2  3  4  5
      6  7  8  9  10
      11 12 13 14 15
      16 17 18 19 20
      21 22 23 24 25
      


*/



/*
It unpacks as a string of 15 bits as follows for the letter 'A':
 second byte        ,    first byte
 Col 3       Col 2       Col 1
 upper rh corner ->0 1 1 1 1   1 0 1 0 0   0 1 1 1 1 <- lower l.h. corner
 top   bot   top   bot   top   bot
 */
prog_uchar charset[] PROGMEM = {
  0,0,     160,3,   24,96,   95,125,  234,83,  146,36,  170,46,  24 ,0,    // 0x20-0x27  !"#$%&'
  46,2,    32,58,   213,85,  196,17,  65,0,    132,16,  0,12,    130,32,   // 0x28-0x2F ()*+,-./
  63,126,  224,3,   183,118, 177,126, 156,124, 189,94,  191,94,  81,114,   // 0x30-0x37 01234567
  191,126, 188,122, 64,1,    65,1,    68,69,   74,41,   81,17,   176,98,   // 0x38-0x3F 89:;<=>?
  174,54,  143,62,  191,42,  63,70,   63,58,   191,70,  159,66,  174,94,   // 0x40-0x47 @ABCDEFG
  159,124, 241,71,  34,120,  159,108, 63,4,    159,125, 223,125, 46,58,    // 0x48-0x4F HIJKLMNO
  159,34,  46,62,   159,46,  169,90,  240,67,  62,124,  124,112, 223,124,  // 0x50-0x57 PQRSTUVW
  155,108, 248,96,  179,102, 63,70,   136,8,   49,126,  8,34,    33,4,     // 0x58-0x5F XYZ[\]^_
  16,1,    163,28,  191,28,  167,20,  162,124, 100,53,  228,81,  165,61,   // 0x60-0x67  abcdefg
  159,12,  224,2,   33,88,   79,20,   241,7,   199,28,  135,12,  162,8,    // 0x68-0x6F hijklmno
  71,17,   68,29,   131,16,  229,41,  228,17,  38,28,   38,24,   103,28,   // 0x70-0x77 pqrstuvw
  69,20,   169,56,  235,53,  100,71,  224,3,   113,19,  8 ,67,   255,127,  // 0x78-0x7F xyz{|}~
}; 

volatile unsigned long ledGrid;
volatile byte led123456;
volatile byte ledABC;
volatile byte touch;

#define KEY_A  26
#define KEY_B  27
#define KEY_C  28

#define SCROLLSPEED  15
#define MOLECOUNT    25

// ---------------------------------------------------------------------------
//
//
//
// ---------------------------------------------------------------------------
void setup(void) {
  byte i;

  for (i=2; i<11; i++) {
    pinMode(i, OUTPUT);
    digitalWrite(i, LOW);
  }

  for (i=11; i<14; i++) {
    pinMode(i, INPUT);
    digitalWrite(i, LOW);  // Turn off pullup
  }

  for (i=14; i<20; i++) {
    pinMode(i, OUTPUT);
    digitalWrite(i, LOW);
  }

  Timer1.initialize(911);  // Prime number
  Timer1.attachInterrupt(RefreshLeds); 
  Serial.begin(9600);
}




void loop(void) {
  byte game;
  byte key;

  ledGrid=0;
  led123456=0;
  ledABC=0;
  game=0;

  for (;;) {
    switch (game) {
    case 0:   
      key=ScrollMessage("LIGHTS OUT ");
      break;
    case 1:
      key=ScrollMessage("SIMON ");
      break;
    case 2:
      key=ScrollMessage("WACK-A-MOLE ");
      break;
    case 3:
      key=ScrollMessage("MAZE ");
      break;
    }
    if (key==0) continue;

    Serial.println(key, DEC);

    if (key==KEY_A) {
      game++;
      if (game>3) game=0;
      ledGrid=0;
      delay(500);      
      continue;
    }

    if (key==KEY_B) {
      if (game==0) PlayLightsOut();
      if (game==1) PlaySimon();
      if (game==2) PlayWhackAMole();
      if (game==3) PlayMaze();
      continue;
    }
  }
}





//
//
//
void RefreshLeds(void) {
  static byte cathode=0;
  byte i,r;

  digitalWrite(8,LOW);
  digitalWrite(9,LOW);
  digitalWrite(10,LOW);

  for (i=2; i<11; i++) {
    digitalWrite(i, LOW);
  }
  for (i=14; i<20; i++) {
    digitalWrite(i, LOW);
  }

  if (cathode==0) {
    if ((ledGrid&0x00000001UL)) digitalWrite(14,HIGH);
    if ((ledGrid&0x00000002UL)) digitalWrite(15,HIGH);
    if ((ledGrid&0x00000004UL)) digitalWrite(16,HIGH);
    if ((ledGrid&0x00000008UL)) digitalWrite(17,HIGH);
    if ((ledGrid&0x00000010UL)) digitalWrite(18,HIGH);
    if ((ledGrid&0x00000020UL)) digitalWrite(19,HIGH);
    if ((ledGrid&0x00000040UL)) digitalWrite(2,HIGH);
    if ((ledGrid&0x00000080UL)) digitalWrite(3,HIGH);
    if ((ledGrid&0x00000100UL)) digitalWrite(4,HIGH);
    if ((ledGrid&0x00000200UL)) digitalWrite(5,HIGH);
    if ((led123456&0x10)) digitalWrite(6,HIGH);
    if ((led123456&0x20)) digitalWrite(7,HIGH);
    digitalWrite(10,HIGH);
  }

  if (cathode==1) {
    if ((ledGrid&0x00000400UL)) digitalWrite(14,HIGH);
    if ((ledGrid&0x00000800UL)) digitalWrite(15,HIGH);
    if ((ledGrid&0x00001000UL)) digitalWrite(16,HIGH);
    if ((ledGrid&0x00002000UL)) digitalWrite(17,HIGH);
    if ((ledGrid&0x00004000UL)) digitalWrite(18,HIGH);
    if ((ledGrid&0x00008000UL)) digitalWrite(19,HIGH);
    if ((ledGrid&0x00010000UL)) digitalWrite(2,HIGH);
    if ((ledGrid&0x00020000UL)) digitalWrite(3,HIGH);
    if ((ledGrid&0x00040000UL)) digitalWrite(4,HIGH);
    if ((ledGrid&0x00080000UL)) digitalWrite(5,HIGH);
    if ((led123456&0x04)) digitalWrite(6,HIGH);
    if ((led123456&0x08)) digitalWrite(7,HIGH);
    digitalWrite(9,HIGH);
  }

  if (cathode==2) {
    if ((ledGrid&0x00100000UL)) digitalWrite(14,HIGH);
    if ((ledGrid&0x00200000UL)) digitalWrite(15,HIGH);
    if ((ledGrid&0x00400000UL)) digitalWrite(16,HIGH);
    if ((ledGrid&0x00800000UL)) digitalWrite(17,HIGH);
    if ((ledGrid&0x01000000UL)) digitalWrite(18,HIGH);
    if ((ledABC&0x01)) digitalWrite(19,HIGH);
    if ((ledABC&0x02)) digitalWrite(2,HIGH);
    if ((ledABC&0x04)) digitalWrite(3,HIGH);
    if ((led123456&0x01)) digitalWrite(6,HIGH);
    if ((led123456&0x02)) digitalWrite(7,HIGH);
    digitalWrite(8,HIGH);
  }

  if (cathode==3) {
    touch=0;
    for (r=0; r<11; r++) {
      digitalWrite(2, HIGH);
      digitalWrite(3, HIGH);
      digitalWrite(4, HIGH);
      digitalWrite(5, HIGH);
      digitalWrite(6, HIGH);
      digitalWrite(7, HIGH);
      digitalWrite(14, HIGH);
      digitalWrite(15, HIGH);
      digitalWrite(16, HIGH);
      digitalWrite(17, HIGH);
      digitalWrite(18, HIGH);
      digitalWrite(19, HIGH);
      if (r==0) digitalWrite(14,LOW);
      if (r==1) digitalWrite(15,LOW);
      if (r==2) digitalWrite(16,LOW);
      if (r==3) digitalWrite(17,LOW);
      if (r==4) digitalWrite(18,LOW);
      if (r==5) digitalWrite(19,LOW);
      if (r==6) digitalWrite(2,LOW);
      if (r==7) digitalWrite(3,LOW);
      if (r==8) digitalWrite(4,LOW);
      if (r==9) digitalWrite(5,LOW);

      if (digitalRead(11)==LOW) touch=1+r;
      if (digitalRead(12)==LOW) touch=11+r;
      if (digitalRead(13)==LOW) touch=21+r;
    }
  }

  cathode++;
  cathode&=0x03;
}










void Rain(void) {
  int r;

  while (touch==28) {
    ledGrid=ledGrid<<5;
    r=random(1,6);
    if (r==1) {
      ledGrid|=(1UL<<random(0,5));
    }
    if (r==2) {
      ledGrid|=(1UL<<random(0,5));
      ledGrid|=(1UL<<random(0,5));
    }
    delay(150);    
  }

}



//
//
//
void DrawCharacterColumn(byte d1, byte d2, byte col) {
  byte i;

  // Shift grid on display one step left
  ledGrid=ledGrid>>1;
  // Turn off all the rightmost pixels
  ledGrid&= ~((1UL<<4)|(1UL<<9)|(1UL<<14)|(1UL<<19)|(1UL<<24));

  // Plot the desired column of pixels from the character map
  // onto the rightmost pixels on the display
  if (col==0) {
    if (d1&1)  ledGrid^=1UL<<24;  
    if (d1&2)  ledGrid^=1UL<<19;  
    if (d1&4)  ledGrid^=1UL<<14;  
    if (d1&8)  ledGrid^=1UL<<9;  
    if (d1&16) ledGrid^=1UL<<4;  
  }
  if (col==1) {
    if (d1&32)  ledGrid^=1UL<<24;  
    if (d1&64)  ledGrid^=1UL<<19;  
    if (d1&128) ledGrid^=1UL<<14;  
    if (d2&1)   ledGrid^=1UL<<9;  
    if (d2&2)   ledGrid^=1UL<<4;  
  }
  if (col==2) {
    if (d2&4)  ledGrid^=1UL<<24;  
    if (d2&8)  ledGrid^=1UL<<19;  
    if (d2&16) ledGrid^=1UL<<14;  
    if (d2&32) ledGrid^=1UL<<9;  
    if (d2&64) ledGrid^=1UL<<4;  
  }

}



//
//
//
byte ScrollMessage(char *s) {
  byte i,col,key,dly, dummy;
  byte v1,v2,ch;

  for (i=0; i<strlen(s); i++) {
    ch=s[i]-32;
    v1 =  pgm_read_byte_near(charset + ch*2);
    v2 =  pgm_read_byte_near(charset + ch*2 +1);
    for (col=0; col<4; col++) {
      if (col==3) {
        DrawCharacterColumn(0,0,0);
      } 
      else {
        DrawCharacterColumn(v1,v2,col);
      }
      for (dly=0; dly<SCROLLSPEED; dly++) {
        dummy=random(100);
        key=touch;
        delay(10);
        if (touch==key && key!=0) return key;
      }
    }
  }
  return 0;
}


//
//
//
void StartAnimation(void) {
  ledGrid=0;
  delay(800);
  ledGrid=33080895UL;
  delay(800);
  ledGrid=469440UL;
  delay(800);
  ledGrid=4096UL;
  delay(800);
  ledGrid=0;
}

//
//
//
void FailAnimation(void) {
  ledGrid=0UL;
  delay(300);
  ledGrid=31UL;
  delay(200);
  ledGrid=992UL;
  delay(200);
  ledGrid=31744UL;
  delay(200);
  ledGrid=1015808UL;
  delay(200);
  ledGrid=32505856UL;
  delay(200);
  ledGrid=0;
}


// ---------------------------------------------------------------------------
//
//
//
// ---------------------------------------------------------------------------
void PlayLightsOut(void) {
  byte flag;
  byte key;


  for (;;) {
    StartAnimation();
    LO_GenerateGameMap();
    flag=0;
    for (;;) {
      key=touch;
      delay(25);
      if (touch!=key) continue;  // Key still bouncing
      if (key==0) {  // No key pressed
        flag=0;
        continue;
      }

      if (key==26) return; // Exit to main menu
      if (key==27) break; // New game

      if (key<26) {          // Key on grid pressed
        if (flag==0) LO_Flip(key-1);
        flag=1;
      }

    } // forever in game
  } // forever new game
}


//
//  
//
void LO_GenerateGameMap(void) {
  byte i;

  ledGrid=0x1ffffff;
  for (i=1; i<100; i++) {
    LO_Flip(random(0,25));    
  }
}


//
//
//
void LO_Flip(byte nr) {
  byte x,y;

  x=nr%5;
  y=nr/5;
  ledGrid^=1UL<<((y)*5+(x));  
  if (y>0) ledGrid^=1UL<<((y-1)*5+(x));   
  if (x>0) ledGrid^=1UL<<((y)*5+(x-1));   
  if (y<4) ledGrid^=1UL<<((y+1)*5+(x));   
  if (x<4) ledGrid^=1UL<<((y)*5+(x+1));   
}




// ---------------------------------------------------------------------------
//
//
//
// ---------------------------------------------------------------------------
void PlayWhackAMole(void) {
  byte key;
  byte t;
  byte mole;
  int  score;  
  byte gameround;
  char stmp[8];

  StartAnimation();

  score=0;
  for (gameround=0; gameround<MOLECOUNT; gameround++) {
    delay(random(800,2500));
    mole=random(0,25);
    ledGrid=1L<<mole;
    led123456=0;
    for(t=0; t<100; t++) {
      key=touch;
      delay(10);
      if (touch!=key) continue;  // Key still bouncing
      if (key>0) {  
        if (key-1==mole) {
          score+=100-t;
          ledGrid=33554431UL;
          delay(100);
          ledGrid=0;
          break;
        }
      }
    }
    ledGrid=0;
  } // for gameround

  ledGrid=0;

  stmp[0]=' ';
  stmp[1]=' ';
  itoa(score, &stmp[2], 10);
  do {
    key=ScrollMessage(stmp);
  } 
  while (key<26);
}


// ---------------------------------------------------------------------------
//
//
//
// ---------------------------------------------------------------------------
void PlaySimon(void) {
  byte key;
  byte t;
  byte mole;
  byte gameround;
  char stmp[10];
  byte sequence[32];
  unsigned long pad[4];
  byte i;
  byte len;
  byte keypad;
  byte gameover;

  pad[0]=99;
  pad[1]=792;
  pad[2]=3244032UL;
  pad[3]=25952256UL;

  StartAnimation();
  for (i=0; i<32; i++) {
    sequence[i]=random(0,4);
  }

  gameover=0;
  for (len=1; len<33; len++) {
    delay(2000);

    // Play sequence
    for (i=0; i<len; i++) {
      ledGrid=pad[sequence[i]];
      delay(800);
      ledGrid=0;
      delay(200);
    }

    // Get sequence from player
    for (i=0; i<len && !gameover; i++) {
      for(t=0; t<250; t++) {  // Timeout of 2.5 seconds
        key=touch;
        delay(10);
        if (touch!=key) continue;  // Key still bouncing

        keypad=255;
        if (key>0) {  
          if (key==1 || key==2 || key==6 || key==7) keypad=0;
          if (key==4 || key==5 || key==9 || key==10) keypad=1;
          if (key==16 || key==17 || key==21 || key==22) keypad=2;
          if (key==19 || key==20 || key==24 || key==25) keypad=3;
          if (sequence[i]==keypad) {
            ledGrid=pad[keypad];
            delay(300);
            ledGrid=0;
            break;
          } 
          else {
            gameover=1; // Wrong key
            break;
          }
        }
      } // for delayloop

      if (t==250) {
        // Timeout
        gameover=1;
      }
    } // for get_user_sequence loop

    if (gameover) {
      FailAnimation();
      break;
    }

  } // for gameround

  ledGrid=0;

  stmp[0]=' ';
  stmp[1]=' ';
  stmp[2]='M';
  stmp[3]='A';
  stmp[4]='X';
  stmp[5]=' ';
  itoa(len-1, &stmp[6], 10);
  do {
    key=ScrollMessage(stmp);
  } 
  while (key<26);
}










// ---------------------------------------------------------------------------
//
//
//
// ---------------------------------------------------------------------------
unsigned long maze[32];

void PlayMaze(void) {
  byte x,y;
  byte px,py;
  byte ox, oy;
  byte done;
  unsigned long mask;
  byte key;
  byte keyflag;
  byte refresh;
  byte cnt;
  byte flash;

  ledGrid=0;
  for (byte y=0; y<32; y++) maze[y]=0;
  GenerateMaze();
  PrintMaze();
  StartAnimation();

  // Find empty space for player to start
  done=0;
  for (px=0; px<8 && !done; px++) {
    for (py=0; py<8 && !done; py++) {
      if (!(maze[py]&(1UL<<px))) done=1;
    }
  }
  
  px=2; py=2;

  ox=0;
  oy=0;
  cnt=0;
  flash=0;
  refresh=1;
  for (;;) {

    if (refresh) {
      ledGrid=0;
      for (y=0; y<5; y++) {
        for (x=0; x<5; x++) {
          if (maze[y+oy]&(1UL<<(x+ox))) ledGrid|=(1UL<<y*5+x);
        }
      }
      refresh=0;
    }
    cnt++;
    if (cnt>30) {
      cnt=0;
      ledGrid^=(1UL<<py*5+px);
    }
    
    key=touch;
    delay(10);
    if (touch!=key) continue;  // Key still bouncing
    if (key==0) {
      keyflag=0;
      continue;
    }
    
    if (key==KEY_A) return;
    if (key==KEY_B) return;
    
    if (keyflag) continue;
  
    if (key==2 || key==3 || key==5) {  // Up
      if (oy>0) {
          if (maze[y+oy-1]&(1UL<<(x+ox))) {
            flash=1;
          } else { 
            oy--;
          }
      }
      refresh=1;
      keyflag=1;
    }
    
    if (key==6 || key==11 || key==16) { //Left
      if (ox>0) {
          if (maze[y+oy]&(1UL<<(x+ox-1))) {
            flash=1;
          } else {
            ox--;
          }
      }
      refresh=1;
      keyflag=1;    
    }
    
    if (key==22 || key==23 || key==24) { //Down
      if (oy<25) {
        if (maze[y+oy+1]&(1UL<<(x+ox))) {
          flash=1;
        } else {  
          oy++;
        }
      }
      refresh=1;
      keyflag=1;    
    }
    
    if (key==10 || key==15 || key==20) { //Right
      if (ox<25) {
        if (maze[y+oy]&(1UL<<(x+ox+1))) {
          flash=1;
        } else {
          ox++;
        }
      }
      refresh=1;
      keyflag=1;    
    }
      
    if (flash) {
      flash=0;
      led123456=0x3f;
      delay(100);
      led123456=0;
    }      
      
  }
  

  
}


void PrintMaze(void) {
  unsigned long mask;
  
  for (byte y=0; y<32; y++) {
    Serial.println();
    mask=1UL;
    for (byte x=0; x<32; x++) {
      if (maze[y] & mask) {
        Serial.print("X");
      } else {
        Serial.print(".");
      }
      mask = mask << 1;
    }
  }
  Serial.println();
}



//
#define WALL_0      0
#define WALL_1      1

// wall constants
#define WALL_N   0x10
#define WALL_E   0x20
#define WALL_S   0x40
#define WALL_W   0x80
#define WALL_ALL 0xF0

//                        N        E        S        W
byte MOVE_X[]   = {       0,       1,       0,      -1 };
byte MOVE_Y[]   = {      -1,       0,       1,       0 };

// AND clear mask for walls
byte WALL[]     = { ~WALL_N, ~WALL_E, ~WALL_S, ~WALL_W };

// dimensions of maze
#define MAZE_X 15
#define MAZE_Y 15

// size of maze
#define MAZE_TOTAL  MAZE_X * MAZE_Y


//
//
//
void MZ_SetPoint(byte x, byte y, byte c) {
  if (c==WALL_1) {
    maze[y] |= (1UL<<x);
  }
}


//
//
//
void GenerateMaze(void) {
  byte *tmpMaze;
  byte curr_x;
  byte curr_y;
  byte dir;

 tmpMaze=(byte*)malloc(MAZE_TOTAL);
 if (tmpMaze==NULL) {
   for (;;) {
     ledGrid=0x1ffffff;
     delay(100);
     ledGrid=0;
     delay(100); 
   }
 }

  // choose random a cell and make it the current cell
  curr_x = random(MAZE_X);
  curr_y = random(MAZE_Y);
  byte curr_i = curr_y * MAZE_X + curr_x;

  // create a maze of cells with all walls up, maze[] is a bit mask
  // upper 4 bits are for what wall is up
  // lowest 2 bits is step back direction
  // 7   6   5   4   3   2   1   0
  // W   S   E   N          D1  D0
  for (byte i = 0; i < MAZE_TOTAL; i++) tmpMaze[i] = WALL_ALL;

  // GENERATE
  byte visited = 1;
  byte poss_dir[] = { 0, 0, 0, 0 };

  while (visited < MAZE_TOTAL) {
    byte dir_cnt = 0;

    // find all neighbors of current cell with all walls intact in order: N E S W
    for (dir = 0; dir < 4; dir++) {
      byte next_x = curr_x + MOVE_X[dir];
      byte next_y = curr_y + MOVE_Y[dir];

      //  check for valid next cell
      if ((0 <= next_x) && (next_x < MAZE_X) && (0 <= next_y) && (next_y < MAZE_Y))
        // check if previously visited
        if (tmpMaze[next_y * MAZE_X + next_x] == WALL_ALL)
          // not visited, so add to possible next cells
          poss_dir[dir_cnt++] = dir;
    }

    if (dir_cnt > 0) {
      // current cell has one or more unvisited neighbors, so choose one at random
      dir = poss_dir[random(dir_cnt)];

      // clear current wall
      tmpMaze[curr_i] &= WALL[dir];

      // make next cell the current cell
      curr_x += MOVE_X[dir];
      curr_y += MOVE_Y[dir];
      curr_i = curr_y * MAZE_X + curr_x;

      // find opposing dir by XOR 0x02, N 0x00 <-> S 0x02, E 0x01 <-> W 0x03
      dir ^= 0x02;

      // clear opposing wall
      tmpMaze[curr_i] &= WALL[dir];

      // step back direction
      tmpMaze[curr_i] |= dir;

      // increment count of visited cells
      visited++;
    } 
    else {
      // reached dead end, backtrack by getting direction back from maze[]
      dir = tmpMaze[curr_i] & 0x03;

      // make prev cell the current cell
      curr_x += MOVE_X[dir];
      curr_y += MOVE_Y[dir];
      curr_i = curr_y * MAZE_X + curr_x;
    }
  }

  // Plot the maze structure into the maze bitmap
  curr_i = 0;
  byte x_ = 0;
  byte y_ = 0;
  for (byte y = 0; y < MAZE_Y; y++) {
    for (byte x = 0; x < MAZE_X; x++) {
      MZ_SetPoint(x_++, y_, WALL_1);
      MZ_SetPoint(x_++, y_, (tmpMaze[curr_i++] & WALL_N) ? WALL_1 : WALL_0); 
    }
    MZ_SetPoint(x_++, y_, WALL_1);
    x_ = 0;
    y_++;

    curr_i -= MAZE_X;
    for (byte x = 0; x < MAZE_X; x++) {
      MZ_SetPoint(x_++, y_, (tmpMaze[curr_i++] & WALL_W) ? WALL_1 : WALL_0);
      MZ_SetPoint(x_++, y_, WALL_0);
    }
    MZ_SetPoint(x_++, y_, WALL_1);
    x_ = 0;
    y_++;
  }
  for (byte x = 0; x < 2 * MAZE_X + 1; x++)
    MZ_SetPoint(x_++, y_, WALL_1);

  free(tmpMaze);
}

