// Pro-Mata Database Seed Script
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Iniciando seed do banco de dados Pro-Mata...');

  try {
    // Create default admin user
    const adminUser = await prisma.user.upsert({
      where: { email: 'admin@promata.com.br' },
      update: {},
      create: {
        email: 'admin@promata.com.br',
        name: 'Administrador Pro-Mata',
        role: 'ADMIN',
        isActive: true,
        createdAt: new Date(),
      },
    });
    console.log('👤 Admin user created/updated:', adminUser.email);

    // Create default research center
    const centro = await prisma.centro.upsert({
      where: { slug: 'pro-mata-pucrs' },
      update: {},
      create: {
        name: 'Centro de Pesquisas e Proteção da Natureza Pró-Mata',
        slug: 'pro-mata-pucrs',
        description: 'Centro de pesquisa da PUCRS dedicado à conservação e pesquisa da Mata Atlântica',
        location: 'São Francisco de Paula, RS',
        coordinates: {
          latitude: -29.4494,
          longitude: -50.3847
        },
        isActive: true,
        createdAt: new Date(),
      },
    });
    console.log('🏢 Research center created/updated:', centro.name);

    // Create sample accommodations
    const accommodations = await Promise.all([
      prisma.accommodation.upsert({
        where: { identifier: 'QUARTO-001' },
        update: {},
        create: {
          identifier: 'QUARTO-001',
          name: 'Quarto Individual 1',
          description: 'Quarto individual com banheiro privativo',
          capacity: 1,
          type: 'INDIVIDUAL',
          amenities: ['wifi', 'banheiro_privativo', 'aquecimento'],
          centroId: centro.id,
          isActive: true,
          pricePerNight: 150.00,
        },
      }),
      prisma.accommodation.upsert({
        where: { identifier: 'QUARTO-002' },
        update: {},
        create: {
          identifier: 'QUARTO-002',
          name: 'Quarto Duplo 1',
          description: 'Quarto duplo com duas camas de solteiro',
          capacity: 2,
          type: 'DUPLO',
          amenities: ['wifi', 'banheiro_privativo', 'aquecimento', 'varanda'],
          centroId: centro.id,
          isActive: true,
          pricePerNight: 220.00,
        },
      }),
      prisma.accommodation.upsert({
        where: { identifier: 'DORMITORIO-001' },
        update: {},
        create: {
          identifier: 'DORMITORIO-001',
          name: 'Dormitório Compartilhado A',
          description: 'Dormitório compartilhado com 6 camas',
          capacity: 6,
          type: 'COMPARTILHADO',
          amenities: ['wifi', 'banheiro_compartilhado', 'armarios'],
          centroId: centro.id,
          isActive: true,
          pricePerNight: 80.00,
        },
      }),
    ]);
    console.log('🛏️  Accommodations created/updated:', accommodations.length);

    // Create sample activity types
    const activityTypes = await Promise.all([
      prisma.activityType.upsert({
        where: { slug: 'trilha-ecologica' },
        update: {},
        create: {
          name: 'Trilha Ecológica',
          slug: 'trilha-ecologica',
          description: 'Caminhada guiada pelas trilhas da mata',
          duration: 180, // 3 hours in minutes
          difficulty: 'MODERADO',
          maxParticipants: 15,
          price: 45.00,
          isActive: true,
        },
      }),
      prisma.activityType.upsert({
        where: { slug: 'observacao-aves' },
        update: {},
        create: {
          name: 'Observação de Aves',
          slug: 'observacao-aves',
          description: 'Atividade de birdwatching com guia especializado',
          duration: 240, // 4 hours
          difficulty: 'FACIL',
          maxParticipants: 10,
          price: 65.00,
          isActive: true,
        },
      }),
      prisma.activityType.upsert({
        where: { slug: 'pesquisa-cientifica' },
        update: {},
        create: {
          name: 'Pesquisa Científica',
          slug: 'pesquisa-cientifica',
          description: 'Participação em atividades de pesquisa científica',
          duration: 480, // 8 hours
          difficulty: 'AVANCADO',
          maxParticipants: 8,
          price: 120.00,
          isActive: true,
        },
      }),
    ]);
    console.log('🔬 Activity types created/updated:', activityTypes.length);

    // Create default settings
    const settings = await prisma.systemSetting.upsert({
      where: { key: 'booking_settings' },
      update: {},
      create: {
        key: 'booking_settings',
        value: {
          maxAdvanceBookingDays: 365,
          minAdvanceBookingHours: 24,
          cancellationDeadlineHours: 48,
          defaultCheckInTime: '14:00',
          defaultCheckOutTime: '11:00',
          allowSameDayBooking: false
        },
        description: 'Configurações gerais para reservas',
        isActive: true,
      },
    });
    console.log('⚙️  System settings created/updated');

    console.log('✅ Seed completado com sucesso!');
    console.log(`👤 Admin: ${adminUser.email}`);
    console.log(`🏢 Centro: ${centro.name}`);
    console.log(`🛏️  Acomodações: ${accommodations.length}`);
    console.log(`🔬 Tipos de atividade: ${activityTypes.length}`);

  } catch (error) {
    console.error('❌ Erro durante o seed:', error);
    throw error;
  }
}

main()
  .catch((e) => {
    console.error('❌ Seed falhou:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });